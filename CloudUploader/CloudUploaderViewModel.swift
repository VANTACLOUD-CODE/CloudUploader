import Foundation
import SwiftUI
import WebKit

class CloudUploaderViewModel: ObservableObject {
    // MARK: - Published UI States
    @Published var apiStatus: String = "Checking..."
    @Published var tokenStatus: String = "Checking..."
    @Published var timeRemaining: String = "Checking..."
    @Published var albumName: String = "Not Set" // Initial placeholder in red
    @Published var shareableLink: String = "N/A" // Initial placeholder in red
    @Published var captureOneStatus: String = "Not processing"
    
    // Buttons controlling
    @Published var showAuthenticateButton: Bool = true
    @Published var showRefreshButton: Bool = false
    
    // SwiftUI states for modals/sheets
    @Published var showAuthRequiredSheet: Bool = false
    @Published var showAuthSheet: Bool = false
    @Published var showAlbumInput: Bool = false
    @Published var showAlbumSelection: Bool = false
    @Published var availableAlbums: [[String: String]] = []
    
    // Visual states
    @Published var remainingTimeColor: Color = .green
    
    // If you need a WKWebView reference for SwiftUI's sheet
    @Published var webView: WKWebView?
    
    // Private file paths
    private let credentialsFilePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/credentials.json"
    private let tokenFilePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
    private let albumInfoPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_info.txt"
    private let albumIdPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_id.txt"
    private let createAlbumScriptPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/create_album.py"
    private let listSharedAlbumsScriptPath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/list_shared_albums.py"
    
    // MARK: - Initialization
    func initialize() {
        fetchStatus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.fetchAlbumInfo()
        }
    }
    
    // MARK: - Status Management
    func fetchStatus() {
        checkAPIStatus()
        checkTokenStatus()
    }
    
    private func checkAPIStatus() {
        DispatchQueue.global().async {
            sleep(1)
            DispatchQueue.main.async {
                self.apiStatus = "✅ Reachable"
            }
        }
    }
    
    private func checkTokenStatus() {
        DispatchQueue.global().async {
            guard FileManager.default.fileExists(atPath: self.tokenFilePath) else {
                DispatchQueue.main.async {
                    self.updateTokenStatus(valid: false, remainingTime: "⌛️")
                }
                return
            }
    
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: self.tokenFilePath))
                if let tokenDetails = self.parseToken(data: data) {
                    DispatchQueue.main.async {
                        let isValid = tokenDetails.remainingTime > 0
                        self.updateTokenStatus(valid: isValid,
                                               remainingTime: "\(tokenDetails.remainingTime) minutes")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.updateTokenStatus(valid: false, remainingTime: "Invalid token")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateTokenStatus(valid: false, remainingTime: "Failed to parse token")
                }
            }
        }
    }
    
    private func updateTokenStatus(valid: Bool, remainingTime: String) {
        tokenStatus = valid ? "✅ Valid" : "❌ Expired"
        timeRemaining = valid ? remainingTime : "⌛️"
        remainingTimeColor = valid ? .green : .red
        showAuthenticateButton = !valid
        showRefreshButton = valid
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
    
    // MARK: - Auth Checking Helpers
    /// If token is invalid, show the SwiftUI "Auth Required" sheet
    func checkOrPromptAuth(onValid: @escaping () -> Void) {
        if tokenStatus.contains("❌") {
            showAuthRequiredSheet = true
        } else {
            onValid()
        }
    }
    
    // MARK: - Album Management
    func fetchAlbumInfo() {
        // We keep line[0] => albumName, line[1] => shareableLink
        DispatchQueue.global().async {
            guard FileManager.default.fileExists(atPath: self.albumIdPath),
                  FileManager.default.fileExists(atPath: self.albumInfoPath) else {
                DispatchQueue.main.async {
                    self.albumName = "Not Set"
                    self.shareableLink = "N/A"
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
                        self.albumName = nameLine.isEmpty ? "Not Set" : nameLine
                        self.shareableLink = linkLine.isEmpty ? "N/A" : linkLine
                    }
                } else {
                    DispatchQueue.main.async {
                        self.albumName = "Not Set"
                        self.shareableLink = "N/A"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.albumName = "Not Set"
                    self.shareableLink = "N/A"
                }
            }
        }
    }
    
    func runNewShootScript(albumName: String) {
        runScript(scriptPath: createAlbumScriptPath, arguments: [albumName]) { output in
            DispatchQueue.main.async {
                self.captureOneStatus = output
            }
        }
    }
    
    func runSelectAlbumScript() {
        runScript(scriptPath: listSharedAlbumsScriptPath, arguments: []) { output in
            guard let albums = try? JSONDecoder().decode([[String: String]].self,
                                                         from: Data(output.utf8)) else {
                DispatchQueue.main.async {
                    self.captureOneStatus = "Failed to parse albums output."
                }
                return
            }
            DispatchQueue.main.async {
                self.availableAlbums = albums
                self.showAlbumSelection = true
            }
        }
    }
    
    // MARK: - Script
    private func runScript(scriptPath: String, arguments: [String],
                           completion: @escaping (String) -> Void) {
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
                } else {
                    completion("Unknown error occurred.")
                }
            } catch {
                completion("Error running script: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Authentication (SwiftUI-based)
    func authenticateInApp() {
        DispatchQueue.main.async {
            let config = WKWebViewConfiguration()
            let web = WKWebView(frame: .zero, configuration: config)
            if let url = self.buildAuthURL() {
                web.load(URLRequest(url: url))
            }
            self.webView = web
            self.showAuthSheet = true
        }
    }
    
    private func buildAuthURL() -> URL? {
        guard let creds = loadCredentials() else { return nil }
        guard let installed = creds["installed"] as? [String: Any],
              let clientId = installed["client_id"] as? String else {
            print("❌ 'client_id' not found in credentials!")
            return nil
        }
        let base = "https://accounts.google.com/o/oauth2/v2/auth"
        // We'll add &login_hint=sirak@sirakstudios.com
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
    
    func copyToClipboard(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }
    
    func confirmQuit() {
        // Encapsulated NS functionality within ViewModel
        NSApplication.shared.terminate(nil)
    }
}
