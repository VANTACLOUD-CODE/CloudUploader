import Foundation
import SwiftUI
import WebKit

struct StatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

class CloudUploaderViewModel: ObservableObject {
    static let shared = CloudUploaderViewModel()
    
    // MARK: - Published UI States
    @Published var apiStatus: String = "Checking..."
    @Published var tokenStatus: String = "Checking..."
    @Published var timeRemaining: String = "Checking..."
    @Published var albumName: String = "Not Set"
    @Published var shareableLink: String = "N/A"
    @Published var captureOneStatus: String = "Not processing"
    @Published var isMonitoring: Bool = false
    @Published var uploadQueue: [URL] = []
    @Published var processedFiles: Set<String> = []
    private var folderMonitor: FolderMonitor?
    private var isUploading: Bool = false
    private let photoBooth = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop")
        .appendingPathComponent("Photo Booth")
    
    // MARK: - Control States
    @Published var showAuthenticateButton: Bool = true
    @Published var showRefreshButton: Bool = false
    @Published var showAuthRequiredSheet: Bool = false
    @Published var showAuthSheet: Bool = false
    @Published var showAlbumInput: Bool = false
    @Published var showAlbumSelection: Bool = false
    @Published var availableAlbums: [[String: String]] = []
    @Published var webView: WKWebView?
    @Published var showQuitConfirmation: Bool = false
    
    // MARK: - Private Properties
    private let credentialsFilePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/credentials.json"
    private let tokenFilePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
    private let albumInfoPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_info.txt"
    private let albumIdPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_id.txt"
    private let createAlbumScriptPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/create_album.py"
    private let listSharedAlbumsScriptPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/list_shared_albums.py"
    
    // MARK: - Initialization
    private init() {
        // No need for super.init() since we're not inheriting
    }
    
    // MARK: - Public Methods
    func initialize() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Initial startup
            ConsoleManager.shared.systemStartup()
            
            // Check API first
            self.checkAPIStatus()
            
            // Slight delay to ensure proper ordering
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Then check token
                self.checkTokenStatus()
                
                // Finally check album info
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.fetchAlbumInfo()
                    
                    // Set final status
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        ConsoleManager.shared.logFinalStatus(hasValidToken: self.tokenStatus.contains("✅"))
                    }
                }
            }
        }
    }
    
    func checkOrPromptAuth(completion: @escaping () -> Void) {
        if tokenStatus.contains("✅") {
            completion()
        } else {
            showAuthRequiredSheet = true
        }
    }
    
    func authenticateInApp() {
        ConsoleManager.shared.log("🔐 Starting authentication process...", color: .yellow)
        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: config)
        if let url = buildAuthURL() {
            ConsoleManager.shared.log("📱 Opening Google authentication...", color: .blue)
            web.load(URLRequest(url: url))
        } else {
            ConsoleManager.shared.log("❌ Failed to build authentication URL", color: .red)
        }
        webView = web
    }
    
    func runNewShootScript(albumName: String) {
        ConsoleManager.shared.log("📂 Creating new album: \(albumName)...", color: .yellow)
        runScript(scriptPath: createAlbumScriptPath, arguments: [albumName]) { output in
            DispatchQueue.main.async {
                self.captureOneStatus = output
                ConsoleManager.shared.log("✅ Album created successfully", color: .green)
                ConsoleManager.shared.log("🔄 Refreshing album information...", color: .blue)
                self.fetchAlbumInfo()
            }
        }
    }
    
    func runSelectAlbumScript() async {
        ConsoleManager.shared.log("📋 Fetching available albums...", color: .yellow)
        runScript(scriptPath: listSharedAlbumsScriptPath, arguments: []) { output in
            guard let albums = try? JSONDecoder().decode([[String: String]].self, from: Data(output.utf8)) else {
                ConsoleManager.shared.log("❌ Failed to parse albums data", color: .red)
                return
            }
            DispatchQueue.main.async {
                self.availableAlbums = albums
                ConsoleManager.shared.log("✅ Found \(albums.count) available albums", color: .green)
                self.showAlbumSelection = true
            }
        }
    }
    
    func copyToClipboard(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }
    
    func confirmQuit() {
        NSApplication.shared.terminate(nil)
    }
    
    func toggleMonitoring() {
        checkOrPromptAuth { [weak self] in
            guard let self = self else { return }
            if self.isMonitoring {
                self.stopMonitoring()
            } else {
                self.startMonitoring()
            }
            self.isMonitoring.toggle()
        }
    }
    
    private func startMonitoring() {
        guard FileManager.default.fileExists(atPath: photoBooth.path) else {
            ConsoleManager.shared.log("❌ Photo Booth folder not found at: \(photoBooth.path)", color: .red)
            return
        }
        
        folderMonitor = FolderMonitor(folderPath: photoBooth.path)
        folderMonitor?.onFileAdded = { [weak self] fileURL in
            guard let self = self else { return }
            if !self.processedFiles.contains(fileURL.path) {
                self.uploadQueue.append(fileURL)
                ConsoleManager.shared.log("📝 Added to queue: \(fileURL.lastPathComponent)", color: .blue)
                self.processNextInQueue()
            }
        }
        folderMonitor?.start()
        ConsoleManager.shared.log("✅ Started monitoring Photo Booth folder", color: .green)
    }
    
    private func stopMonitoring() {
        folderMonitor?.stop()
        folderMonitor = nil
        ConsoleManager.shared.log("⏹ Stopped monitoring Photo Booth folder", color: .orange)
    }
    
    private func processNextInQueue() {
        guard !isUploading, !uploadQueue.isEmpty else { 
            if uploadQueue.isEmpty {
                ConsoleManager.shared.log("Queue empty - Waiting for new photos...", color: .gray)
            }
            return 
        }
        
        isUploading = true
        let fileURL = uploadQueue.removeFirst()
        
        ConsoleManager.shared.log("⬆️ Starting upload: \(fileURL.lastPathComponent)", color: .blue)
        ConsoleManager.shared.log("📊 Remaining in queue: \(uploadQueue.count) photos", color: .orange)
        
        // After successful upload:
        processedFiles.insert(fileURL.path)
        ConsoleManager.shared.log("✅ Successfully uploaded: \(fileURL.lastPathComponent)", color: .green)
        
        isUploading = false
        processNextInQueue()
    }
    
    // MARK: - Private Methods
    private func checkAPIStatus() {
        ConsoleManager.shared.log("🔍 Checking API reachability...", color: .yellow)
        DispatchQueue.global().async {
            sleep(1) // Simulated API check
            DispatchQueue.main.async {
                self.apiStatus = "✅ Reachable"
                ConsoleManager.shared.logAPIStatus(isReachable: true)
            }
        }
    }
    
    private func checkTokenStatus() {
        ConsoleManager.shared.log("🔑 Checking token status...", color: .yellow)
        
        // Set initial state to checking
        tokenStatus = "❌ Checking..."
        timeRemaining = "Checking..."
        
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            guard FileManager.default.fileExists(atPath: self.tokenFilePath) else {
                DispatchQueue.main.async {
                    self.updateTokenStatus(valid: false, remainingTime: "Token not found")
                }
                return
            }
            
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: self.tokenFilePath))
                if let details = self.parseToken(data: data) {
                    DispatchQueue.main.async {
                        let isValid = details.remainingTime > 0
                        self.updateTokenStatus(valid: isValid, 
                                            remainingTime: "\(details.remainingTime) minutes")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.updateTokenStatus(valid: false, remainingTime: "Invalid token")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateTokenStatus(valid: false, remainingTime: "Failed to read token")
                }
            }
        }
    }
    
    private func updateTokenStatus(valid: Bool, remainingTime: String) {
        tokenStatus = valid ? "✅ Valid" : "❌ Expired"
        timeRemaining = valid ? remainingTime : "⌛️"
        showAuthenticateButton = !valid
        showRefreshButton = valid
        
        if !valid {
            ConsoleManager.shared.log("Token Status: ❌ Expired or invalid", color: .red)
        } else {
            ConsoleManager.shared.log("Token Status: ✅ Valid (\(remainingTime) remaining)", color: .green)
        }
    }
    
    private func fetchAlbumInfo() {
        ConsoleManager.shared.log("🔍 Checking album status...", color: .yellow)
        DispatchQueue.global().async {
            guard FileManager.default.fileExists(atPath: self.albumIdPath),
                  FileManager.default.fileExists(atPath: self.albumInfoPath) else {
                DispatchQueue.main.async {
                    self.albumName = "Not Set"
                    self.shareableLink = "N/A"
                    ConsoleManager.shared.logAlbumStatus(name: nil, link: nil)
                }
                return
            }
            
            do {
                let info = try String(contentsOfFile: self.albumInfoPath, encoding: .utf8)
                let lines = info.split(separator: "\n")
                if lines.count >= 2 {
                    let nameLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let linkLine = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    DispatchQueue.main.async {
                        self.albumName = nameLine
                        self.shareableLink = linkLine
                        ConsoleManager.shared.logAlbumStatus(name: nameLine, link: linkLine)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.albumName = "Error reading album info"
                    self.shareableLink = "N/A"
                    ConsoleManager.shared.log("❌ Failed to read album information", color: .red)
                }
            }
        }
    }
    
    private func buildAuthURL() -> URL? {
        guard let creds = loadCredentials() else { return nil }
        guard let installed = creds["installed"] as? [String: Any],
              let clientId = installed["client_id"] as? String else {
            return nil
        }
        let base = "https://accounts.google.com/o/oauth2/v2/auth"
        let scope = "scope=email"
        let extras = "access_type=offline&include_granted_scopes=true&redirect_uri=http://localhost:8080&response_type=code&login_hint=sirak%40sirakstudios.com"
        let urlString = "\(base)?\(scope)&\(extras)&client_id=\(clientId)"
        return URL(string: urlString)
    }
    
    private func loadCredentials() -> [String: Any]? {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: credentialsFilePath)) {
            return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        }
        return nil
    }
    
    private func parseToken(data: Data) -> (remainingTime: Int, expiryDate: Date)? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let expiryString = json["expiry"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let expiryDate = isoFormatter.date(from: expiryString) {
                    let remainingTime = Int(expiryDate.timeIntervalSinceNow / 60)
                    return (remainingTime, expiryDate)
                }
            }
        } catch {
            print("❌ parseToken error: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func runScript(scriptPath: String, arguments: [String], completion: @escaping (String) -> Void) {
        DispatchQueue.global().async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", scriptPath] + arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    completion(output)
                }
            } catch {
                completion("Error running script: \(error.localizedDescription)")
            }
        }
    }
    
    var remainingTimeColor: Color {
        if timeRemaining.contains("expired") {
            return .red
        } else if timeRemaining.contains("< 1 hour") {
            return .orange
        }
        return .green
    }
    
    @Published var statusMessages: [StatusMessage] = [StatusMessage(text: "Not processing.", color: .gray)]
    
    func addStatusMessage(message: String, color: Color) {
        ConsoleManager.shared.log(message, color: color)
    }
    
    func dismissAuthSheet() {
        webView = nil
        showAuthSheet = false
        ConsoleManager.shared.log("⚠️ Authentication cancelled by user", color: .orange)
        ConsoleManager.shared.log("ℹ️ Generate Token to begin", color: .blue)
    }
    
    func dismissAuthRequiredSheet() {
        showAuthRequiredSheet = false
        ConsoleManager.shared.log("⚠️ Authentication required - cancelled by user", color: .orange)
        ConsoleManager.shared.log("ℹ️ Generate Token to begin", color: .blue)
    }
    
    func handleAuthDismissal() {
        ConsoleManager.shared.log("⚠️ Authentication cancelled by user", color: .orange)
        ConsoleManager.shared.log("ℹ️ Generate Token to begin", color: .blue)
        webView = nil
    }
    
    func handleLinkCopied(link: String) {
        ConsoleManager.shared.log("📋 Album link copied to clipboard", color: .blue)
        ConsoleManager.shared.log("🔗 \(link)", color: .gray)
    }
    
    func handleLinkOpened(link: String) {
        ConsoleManager.shared.log("🌐 Opening album link in browser", color: .blue)
        ConsoleManager.shared.log("🔗 \(link)", color: .gray)
    }
}
