import Foundation
import SwiftUI
@preconcurrency import WebKit
import UserNotifications

struct StatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

struct VerifyAlbumResponse: Codable {
    let status: String
    let message: String?
}

@MainActor
class CloudUploaderViewModel: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = CloudUploaderViewModel()
    
    // MARK: - Published Properties
    @Published var apiStatus: String = "🔄 Checking..."
    @Published var tokenStatus: String = "🔄 Checking..."
    @Published var timeRemaining: String = "🔄 Checking..."
    
    // Add TokenManager instance with proper initialization
    let tokenManager: TokenManager
    
    override init() {
        self.tokenManager = TokenManager()
        super.init()
        
        // Bind to tokenManager button states
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
                self?.timeRemaining = self?.tokenManager.countdownDisplay ?? "--:-- ⌛️"
                self?.showAuthenticateButton = self?.tokenManager.showAuthenticateButton ?? true
                self?.showRefreshButton = self?.tokenManager.showRefreshButton ?? false
            }
        }
        
        Task {
            await checkTokenStatus()
        }
    }
    
    // MARK: - Published UI States
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
    @Published var availableAlbums: [AlbumInfo] = []
    @Published var webView: WKWebView?
    @Published var showQuitConfirmation: Bool = false
    @Published var showSuccessOverlay: Bool = false
    @Published var showNotificationBanner: Bool = false
    @Published var notificationMessage: String = ""
    @Published var notificationColor: Color = .green
    @Published var showAlbumSheet: Bool = false
    @Published var showAlbumRequiredSheet: Bool = false
    @Published var isLoadingAlbums: Bool = false
    
    // MARK: - Private Properties
    private let tokenFilePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
    private let credentialsFilePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/credentials.json"
    private let albumInfoPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_info.txt"
    private let albumIdPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_id.txt"
    private let createAlbumScriptPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/create_album.py"
    private let listSharedAlbumsScriptPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/list_shared_albums.py"
    private let verifyAlbumScriptPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/verify_album.py"
    private let newShootScriptPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/create_album.py"
    
    // MARK: - Public Methods
    func initialize() {
        Task {
            // Initial startup
            ConsoleManager.shared.systemStartup()
            
            // Check API first
            checkAPIStatus()
            
            // Slight delay to ensure proper ordering
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Then check token
            await checkTokenStatus()
            
            // Finally check album info
            try? await Task.sleep(nanoseconds: 500_000_000)
            fetchAlbumInfo()
            
            // Set final status
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                ConsoleManager.shared.logFinalStatus(hasValidToken: self.tokenStatus.contains("✅"))
            }
        }
    }
    
    func checkOrPromptAuth(completion: @escaping () -> Void) {
        if tokenManager.tokenStatus.contains("✅") {
            showAuthenticateButton = false
            showRefreshButton = true
            completion()
        } else {
            showAuthenticateButton = true
            showRefreshButton = false
            showAuthRequiredSheet = true
        }
    }
    
    func authenticateInApp() {
        ConsoleManager.shared.log("🔐 Starting authentication process...", color: Color.orange.opacity(0.9))
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        
        if let url = buildAuthURL() {
            ConsoleManager.shared.log("📱 Opening Google authentication...", color: .blue)
            web.load(URLRequest(url: url))
        } else {
            ConsoleManager.shared.log("❌ Failed to build authentication URL", color: .red)
        }
        webView = web
    }
    
    func runNewShootScript(albumName: String) {
        ConsoleManager.shared.log("📂 Creating new album: \(albumName)...", color: .blue)
        
        runScript(scriptPath: newShootScriptPath, arguments: [albumName]) { [weak self] output in
            guard let self = self else { return }
            
            // Extract JSON from the output
            if let jsonStart = output.firstIndex(of: "{"),
               let jsonEnd = output.lastIndex(of: "}") {
                let jsonString = String(output[jsonStart...jsonEnd])
                
                if let data = jsonString.data(using: .utf8),
                   let response = try? JSONDecoder().decode(AlbumResponse.self, from: data),
                   let album = response.albums?.first {
                    DispatchQueue.main.async {
                        self.albumName = album.title
                        self.shareableLink = album.shareableUrl
                        ConsoleManager.shared.log("✅ Album created successfully: \(album.title)", color: .green)
                        self.saveAlbumId(album.id)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    ConsoleManager.shared.log("❌ Failed to create album: Invalid response format", color: .red)
                }
            }
        }
    }
    
    func runSelectAlbumScript() async {
        ConsoleManager.shared.log("📋 Fetching available albums...", color: .yellow)
        
        DispatchQueue.main.async {
            self.showAlbumSelection = true
            self.isLoadingAlbums = true
        }
        
        runScript(scriptPath: listSharedAlbumsScriptPath, arguments: []) { [weak self] output in
            guard let self = self else { return }
            
            // Clean the output by finding the JSON content
            let cleanedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedOutput.isEmpty else {
                ConsoleManager.shared.log("❌ Empty response from script", color: .red)
                return
            }
            
            guard let data = cleanedOutput.data(using: .utf8) else {
                ConsoleManager.shared.log("❌ Failed to convert output to data", color: .red)
                return
            }
            
            do {
                let response = try JSONDecoder().decode(AlbumResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.isLoadingAlbums = false
                    
                    if let error = response.error {
                        ConsoleManager.shared.log("❌ Error fetching albums: \(error)", color: .red)
                        return
                    }
                    
                    if let albums = response.albums {
                        self.availableAlbums = albums
                        if albums.isEmpty {
                            ConsoleManager.shared.log("ℹ️ No albums found", color: .orange)
                        } else {
                            ConsoleManager.shared.log("✅ Found \(albums.count) available albums", color: .green)
                        }
                    }
                }
            } catch {
                ConsoleManager.shared.log("❌ Failed to parse albums data: \(error)", color: .red)
                print("Debug - Parse error: \(error)")
            }
        }
    }
    
    func copyToClipboard(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }
    
    func confirmQuit() {
        stopMonitoring()
        isMonitoring = false
        ConsoleManager.shared.log("⏹️ Monitoring stopped for quit", color: .orange)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
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
        ConsoleManager.shared.log("🔍 Checking API reachability...", color: Color.orange.opacity(0.9))
        
        // First check if we can reach Google's servers
        let url = URL(string: "https://www.google.com")!
        let task = URLSession.shared.dataTask(with: url) { [weak self] _, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.apiStatus = "✅ Reachable"
                    ConsoleManager.shared.logAPIStatus(isReachable: true)
                    
                    // Now run the test_api.py script for detailed API check
                    self.runDetailedAPICheck()
                } else {
                    self.apiStatus = "❌ Not Reachable"
                    ConsoleManager.shared.logAPIStatus(isReachable: false)
                }
            }
        }
        task.resume()
    }
    
    private func runDetailedAPICheck() {
        runScript(scriptPath: "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/test_api.py", arguments: []) { output in
            if let jsonData = output.data(using: .utf8),
               let response = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let status = response["status"] as? String {
                
                DispatchQueue.main.async {
                    if status == "API reachable" {
                        ConsoleManager.shared.log("✅ Google Photos API is accessible", color: .green)
                    } else if let error = response["error"] as? String {
                        ConsoleManager.shared.log("⚠️ API Status Note: \(error)", color: .orange)
                    }
                }
            }
        }
    }
    
    private func checkTokenStatus() async {
        ConsoleManager.shared.log("🔑 Checking token status...", color: Color.orange.opacity(0.9))
        await MainActor.run {
            tokenManager.checkTokenStatus()
            tokenStatus = tokenManager.tokenStatus
            timeRemaining = tokenManager.timeRemaining
        }
    }
    
    private func fetchAlbumInfo() {
        ConsoleManager.shared.log("🔍 Checking album status...", color: Color.orange.opacity(0.9))
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
        
        // Define all required scopes
        let scopes = [
            "https://www.googleapis.com/auth/photoslibrary",
            "https://www.googleapis.com/auth/photoslibrary.sharing",
            "https://www.googleapis.com/auth/photoslibrary.appendonly",
            "https://www.googleapis.com/auth/photoslibrary.readonly"
        ].joined(separator: " ")
        
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: "http://localhost"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        return components?.url
    }
    
    private func loadCredentials() -> [String: Any]? {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: credentialsFilePath)) {
            return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        }
        return nil
    }
    
    @MainActor
    func parseToken(data: Data) async -> (remainingTime: Int, expiryDate: Date)? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let expiryString = json["expiry"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
                
                if let expiryDate = isoFormatter.date(from: expiryString) {
                    let now = Date()
                    let remainingSeconds = expiryDate.timeIntervalSinceNow
                    
                    // Convert to minutes, ensuring we round up for partial minutes
                    let remainingMinutes = Int(ceil(remainingSeconds / 60))
                    
                    // Format the display string
                    let displayTime = if remainingMinutes <= 0 {
                        "Expired"
                    } else if remainingMinutes >= 60 {
                        "60 minutes"
                    } else {
                        "\(remainingMinutes) minutes"
                    }
                    
                    // Debug logging
                    ConsoleManager.shared.log("📅 Token expiry: \(expiryString)", color: .gray)
                    ConsoleManager.shared.log("⏱️ Remaining time: \(displayTime)", color: .green)
                    ConsoleManager.shared.log("🔍 Debug: Token expiry = \(expiryDate)", color: .gray)
                    ConsoleManager.shared.log("🔍 Debug: Current time = \(now)", color: .gray)
                    ConsoleManager.shared.log("🔍 Debug: Raw remaining minutes = \(remainingMinutes)", color: .gray)
                    
                    return (remainingMinutes, expiryDate)
                }
            }
        } catch {
            ConsoleManager.shared.log("❌ parseToken error: \(error.localizedDescription)", color: .red)
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
    
    func handleAuthCode(_ code: String) {
        ConsoleManager.shared.log("🔐 Authorization code received, processing...", color: .blue)
        
        runScript(scriptPath: "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/token_exchange.py", arguments: [code]) { [weak self] output in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if output.contains("success") {
                    self.handleSuccessfulAuth()
                } else {
                    self.handleFailedAuth(error: .authenticationFailed(output))
                }
            }
        }
    }
    
    private func handleSuccessfulAuth() {
        Task {
            ConsoleManager.shared.log("✅ Token generated successfully", color: .green)
            showBannerNotification(message: "Authentication Successful!")
            
            await MainActor.run {
                showAuthSheet = false
                webView = nil
            }
            
            // Wait for file system
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Update token status
            await checkTokenStatus()
        }
    }
    
    private func handleFailedAuth(error: CloudUploaderError) {
        ConsoleManager.shared.log("❌ \(error.localizedDescription)", color: .red)
        showAuthSheet = false
        webView = nil
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    private func sendAuthSuccessNotification() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "Authentication Successful"
                content.body = "Token generated and saved successfully"
                content.sound = UNNotificationSound.default
                content.interruptionLevel = .timeSensitive
                content.categoryIdentifier = "AUTH_SUCCESS"
                
                // Create notification category for alert-style
                let category = UNNotificationCategory(
                    identifier: "AUTH_SUCCESS",
                    actions: [],
                    intentIdentifiers: [],
                    hiddenPreviewsBodyPlaceholder: "",
                    options: [.customDismissAction, .hiddenPreviewsShowTitle]
                )
                
                // Register the category
                let center = UNUserNotificationCenter.current()
                center.setNotificationCategories([category])
                
                // Create immediate trigger
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                
                let request = UNNotificationRequest(
                    identifier: "auth-success-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )
                
                try await center.add(request)
                ConsoleManager.shared.log("📱 Notification sent", color: .green)
            }
        } catch {
            ConsoleManager.shared.log("⚠️ Failed to send notification: \(error.localizedDescription)", color: .orange)
        }
    }
    
    private func showBannerNotification(message: String, color: Color = .green) {
        Task { @MainActor in
            notificationMessage = message
            notificationColor = color
            withAnimation {
                showNotificationBanner = true
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            withAnimation {
                showNotificationBanner = false
            }
        }
    }
    
    func checkOrPromptAlbum(completion: @escaping () -> Void) {
        // First check if files exist
        guard FileManager.default.fileExists(atPath: albumIdPath),
              FileManager.default.fileExists(atPath: albumInfoPath) else {
            DispatchQueue.main.async {
                self.showAlbumRequiredSheet = true
            }
            return
        }
        
        // Verify album is valid and accessible
        runScript(scriptPath: verifyAlbumScriptPath, arguments: []) { [weak self] output in
            guard let self = self else { return }
            
            print("Debug - Album verification output: \(output)")
            
            // Extract just the JSON part from the output
            if let jsonStart = output.firstIndex(of: "{"),
               let jsonEnd = output.lastIndex(of: "}") {
                let jsonString = String(output[jsonStart...jsonEnd])
                
                if let data = jsonString.data(using: .utf8),
                   let response = try? JSONDecoder().decode(VerifyAlbumResponse.self, from: data) {
                    
                    DispatchQueue.main.async {
                        if response.status == "success" {
                            self.showAlbumRequiredSheet = false
                            completion()
                        } else {
                            self.showAlbumRequiredSheet = true
                            ConsoleManager.shared.log("⚠️ Album verification failed: \(response.message ?? "Unknown error")", color: .orange)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showAlbumRequiredSheet = true
                        ConsoleManager.shared.log("❌ Failed to verify album status", color: .red)
                    }
                }
            }
        }
    }
    
    func fetchAvailableAlbums() async {
        ConsoleManager.shared.log("📋 Fetching available albums...", color: .yellow)
        isLoadingAlbums = true
        
        let albumsCachePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/albums_cache.json"
        
        runScript(scriptPath: listSharedAlbumsScriptPath, arguments: []) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isLoadingAlbums = false
                
                guard FileManager.default.fileExists(atPath: albumsCachePath),
                      let jsonData = try? Data(contentsOf: URL(fileURLWithPath: albumsCachePath)),
                      let response = try? JSONDecoder().decode(AlbumResponse.self, from: jsonData) else {
                    ConsoleManager.shared.log("❌ Failed to read albums cache", color: .red)
                    self.availableAlbums = []
                    return
                }
                
                if let error = response.error {
                    ConsoleManager.shared.log("❌ Error fetching albums: \(error)", color: .red)
                    self.availableAlbums = []
                    return
                }
                
                if let albums = response.albums {
                    self.availableAlbums = albums
                    if albums.isEmpty {
                        ConsoleManager.shared.log("ℹ️ No albums found", color: .orange)
                    } else {
                        ConsoleManager.shared.log("✅ Found \(albums.count) available albums", color: .green)
                    }
                }
            }
        }
    }
    
    func selectAlbum(_ albumName: String) {
        guard let selectedAlbum = availableAlbums.first(where: { $0.title == albumName }) else {
            ConsoleManager.shared.log("❌ Failed to find selected album", color: .red)
            return
        }
        
        do {
            // Write album ID to file
            try selectedAlbum.id.write(toFile: self.albumIdPath, atomically: true, encoding: .utf8)
            
            // Write album info (title and URL) to file
            let albumInfo = "\(selectedAlbum.title)\n\(selectedAlbum.shareableUrl)"
            try albumInfo.write(toFile: self.albumInfoPath, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async {
                self.albumName = selectedAlbum.title
                self.shareableLink = selectedAlbum.shareableUrl
                self.fetchAlbumInfo()
                ConsoleManager.shared.log("✅ Album selected: \(albumName)", color: .green)
            }
        } catch {
            ConsoleManager.shared.log("❌ Failed to save album information: \(error.localizedDescription)", color: .red)
        }
    }
    
    private func saveAlbumId(_ albumId: String) {
        do {
            // Save album ID
            try albumId.write(toFile: albumIdPath, atomically: true, encoding: .utf8)
            
            // Get the current album info from the viewModel
            let albumInfo = "\(albumName)\n\(shareableLink)"
            try albumInfo.write(toFile: albumInfoPath, atomically: true, encoding: .utf8)
            
            // After saving both files, fetch album info to update UI
            fetchAlbumInfo()
            ConsoleManager.shared.log("✅ Album information saved successfully", color: .green)
        } catch {
            ConsoleManager.shared.log("❌ Failed to save album information: \(error.localizedDescription)", color: .red)
        }
    }
}

extension CloudUploaderViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           url.host == "localhost" {
            if let code = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first(where: { $0.name == "code" })?.value {
                decisionHandler(.cancel)
                handleAuthCode(code)
                return
            }
        }
        decisionHandler(.allow)
    }
}

enum CloudUploaderError: LocalizedError {
    case authenticationFailed(String)
    case tokenExpired
    case networkError(String)
    case fileSystemError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .tokenExpired:
            return "Token has expired. Please re-authenticate."
        case .networkError(let message):
            return "Network error: \(message)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        }
    }
}

struct SuccessOverlayView: View {
    var body: some View {
        VStack {
            Text("✅ Authentication Successful")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
                .shadow(radius: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
        .transition(.opacity)
    }
}

struct AlbumInfo: Codable, Identifiable, Hashable {
    let title: String
    let id: String
    let shareableUrl: String
    let isWriteable: Bool
    let totalMediaItems: String
    
    // Computed property to satisfy Identifiable
    var identifier: String { id }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AlbumInfo, rhs: AlbumInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct AlbumResponse: Codable {
    let albums: [AlbumInfo]?
    let error: String?
}
