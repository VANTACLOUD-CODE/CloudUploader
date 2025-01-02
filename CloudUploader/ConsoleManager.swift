import SwiftUI

class ConsoleManager: ObservableObject {
    static let shared = ConsoleManager()
    
    @Published var consoleText: [(text: String, color: Color)] = []
    private let maxLines = 1000
    
    private init() {}
    
    // MARK: - System Messages
    func systemStartup() {
        clear()
        log("🔄 System Initializing...", color: .gray)
        log("🚀 Cloud Uploader Started", color: .green)
        log("----------------------------------------", color: .gray)
        log("⚙️ Performing initial system checks...", color: .gray)
    }
    
    // MARK: - Authentication Messages
    func logAuthStatus(status: String, isValid: Bool) {
        log("🔑 Token Status: \(isValid ? "✅" : "❌") \(status)", 
            color: isValid ? .green : .red)
    }
    
    func logAuthProcess(step: String) {
        log("🔐 Authentication: \(step)", color: .orange.opacity(0.9))
    }
    
    func logAuthCancelled() {
        log("⚠️ Authentication cancelled by user", color: .orange)
        log("ℹ️ Generate Token to begin", color: .blue)
    }
    
    // MARK: - API Status Messages
    func logAPIStatus(isReachable: Bool) {
        if isReachable {
            log("✅ API Status: Connection Successful", color: .green)
        } else {
            log("❌ API Status: Unreachable", color: .red)
        }
    }
    
    // MARK: - Album Messages
    func logAlbumOperation(operation: String, details: String) {
        log("📂 Album \(operation): \(details)", color: .blue)
    }
    
    func logAlbumStatus(name: String?, link: String?) {
        if let name = name, !name.isEmpty {
            log("📁 Current Album: \(name)", color: .blue)
            if let link = link, !link.isEmpty {
                log("🔗 Shareable Link: \(link)", color: .blue)
            }
        } else {
            log("⚠️ No album selected", color: .orange)
        }
    }
    
    // MARK: - Link Messages
    func logLinkCopied(link: String) {
        log("📋 Link copied to clipboard", color: .blue)
        log("🔗 \(link)", color: .gray)
    }
    
    func logLinkOpened(link: String) {
        log("🌐 Opening link in browser", color: .blue)
        log("🔗 \(link)", color: .gray)
    }
    
    func logQRCodeDisplayed() {
        log("📱 Displaying QR code for easy mobile access", color: .blue)
    }
    
    // MARK: - Final Status Messages
    func logFinalStatus(hasValidToken: Bool) {
        log("----------------------------------------", color: .gray)
        if hasValidToken {
            log("Cloud Uploader Ready - Click Start to Begin", color: .green)
        } else {
            log("⚠️ No valid token found", color: .red)
            log("ℹ️ Generate Token to begin", color: .blue)
        }
    }
    
    // Base logging method with adjusted default color
    func log(_ message: String, color: Color = Color.blue.opacity(0.9)) {
        DispatchQueue.main.async {
            let timestamp = Self.getCurrentTimestamp()
            let formattedMessage = "[\(timestamp)] \(message)"
            self.objectWillChange.send()
            self.consoleText.append((formattedMessage, color))
            
            if self.consoleText.count > self.maxLines {
                self.consoleText.removeFirst(self.consoleText.count - self.maxLines)
            }
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.consoleText.removeAll()
        }
    }
    
    private static func getCurrentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

