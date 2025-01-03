import Foundation
import SwiftUI

class TokenManager: ObservableObject {
    // MARK: - Published Properties
    @Published var tokenStatus: String = "🔄 Checking..."
    @Published var timeRemaining: String = "🔄 Checking..."
    @Published var remainingTimeColor: Color = .orange
    @Published var countdownDisplay: String = "--:-- ⌛️"

    // Show/hide "Authenticate" or "Refresh" buttons
    @Published var showAuthenticateButton: Bool = true
    @Published var showRefreshButton: Bool = false

    // If you want to store the short-lived access token in memory:
    @Published var accessToken: String?

    // Paths or Keychain references
    private let tokenFilePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"

    // Add timer property
    private var countdownTimer: Timer?
    private var expiryDate: Date?
    private var remainingMinutes: Int = 0
    private var remainingSeconds: Int = 0

    // MARK: - Init
    init() {
        checkTokenStatus()
        DispatchQueue.main.async { [weak self] in
            self?.startCountdownTimer()
            // Force an immediate update
            self?.updateCountdown()
        }
    }

    deinit {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func updateCountdown() {
        guard let expiryDate = self.expiryDate else { return }
        
        let remainingSeconds = Int(ceil(expiryDate.timeIntervalSinceNow))
        if remainingSeconds > 0 {
            let mins = remainingSeconds / 60
            let secs = remainingSeconds % 60
            
            DispatchQueue.main.async {
                self.countdownDisplay = String(format: "%02d:%02d ⌛️", mins, secs)
                self.remainingMinutes = mins
                self.remainingSeconds = secs
                
                if mins >= 15 {
                    self.remainingTimeColor = .green
                } else if mins >= 5 {
                    self.remainingTimeColor = .orange
                } else {
                    self.remainingTimeColor = .red
                }
            }
        } else {
            DispatchQueue.main.async {
                self.countdownDisplay = "--:-- ⌛️"
                self.remainingTimeColor = .red
                self.checkTokenStatus()
            }
        }
    }

    // MARK: - Check Token
    func checkTokenStatus() {
        ConsoleManager.shared.log("🔍 Checking token...", color: .gray)
        
        guard FileManager.default.fileExists(atPath: tokenFilePath) else {
            ConsoleManager.shared.log("❌ Token not found", color: .red)
            updateTokenStatus(valid: false, remainingTime: "⌛️ --:--")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: tokenFilePath))
            if let details = parseToken(data: data) {
                let isValid = details.remainingTime > 0
                updateTokenStatus(valid: isValid, remainingTime: "\(details.remainingTime)")
                startCountdownTimer()
            } else {
                ConsoleManager.shared.log("❌ Failed to parse token data", color: .red)
                updateTokenStatus(valid: false, remainingTime: "⌛️ --:--")
            }
        } catch {
            ConsoleManager.shared.log("❌ Error reading token: \(error.localizedDescription)", color: .red)
            updateTokenStatus(valid: false, remainingTime: "⌛️ --:--")
        }
    }

    // MARK: - Save / Load Refresh Token
    func saveRefreshToken(_ refreshToken: String) {
        guard let tokenData = try? Data(contentsOf: URL(fileURLWithPath: tokenFilePath)),
              var tokenJson = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any] else {
            return
        }
        
        tokenJson["refresh_token"] = refreshToken
        
        if let updatedData = try? JSONSerialization.data(withJSONObject: tokenJson) {
            try? updatedData.write(to: URL(fileURLWithPath: tokenFilePath))
        }
    }

    func loadRefreshToken() -> String? {
        guard let tokenData = try? Data(contentsOf: URL(fileURLWithPath: tokenFilePath)),
              let tokenJson = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let refreshToken = tokenJson["refresh_token"] as? String else {
            return nil
        }
        return refreshToken
    }

    // MARK: - Refresh Logic
    func refreshToken() {
        ConsoleManager.shared.log("🔄 Refreshing token...", color: .blue)
        
        guard let refreshToken = loadRefreshToken() else {
            ConsoleManager.shared.log("❌ No refresh token found", color: .red)
            return
        }
        
        // Run the refresh token script
        runScript(scriptPath: "/Volumes/CloudUploader/CloudUploader/CloudUploader/Scripts/refresh_token.py", 
                  arguments: [refreshToken]) { [weak self] output in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if output.contains("success") {
                    ConsoleManager.shared.log("✅ Token refreshed successfully", color: .green)
                    self.checkTokenStatus() // Update the UI with new token info
                } else {
                    ConsoleManager.shared.log("❌ Token refresh failed: \(output)", color: .red)
                    // Reset states if refresh failed
                    self.updateTokenStatus(valid: false, remainingTime: "0")
                }
            }
        }
    }

    private func runScript(scriptPath: String, arguments: [String], completion: @escaping (String) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptPath] + arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                completion(output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {
            completion("Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Internal Helpers
    private func updateTokenStatus(valid: Bool, remainingTime: String) {
        let minutes = Int(remainingTime) ?? 0
        let isValid = minutes > 0
        
        tokenStatus = isValid ? "✅ Valid" : "❌ Expired"
        
        // Format time remaining display with colored text
        if !isValid {
            timeRemaining = "--:-- ⌛️"
            remainingTimeColor = .red
        } else {
            // Format as MM:SS
            let totalSeconds = minutes * 60
            let mins = totalSeconds / 60
            let secs = totalSeconds % 60
            timeRemaining = String(format: "%02d:%02d ⌛️", mins, secs)
            
            if mins >= 15 {
                remainingTimeColor = .green
            } else if mins >= 5 {
                remainingTimeColor = .orange
            } else {
                remainingTimeColor = .red
            }
        }
        
        // Update button visibility states
        showAuthenticateButton = !isValid
        showRefreshButton = isValid
        
        // Log status
        if !isValid {
            ConsoleManager.shared.log("Token Status: ❌ Expired or invalid", color: .red)
        } else {
            ConsoleManager.shared.log("Token Status: ✅ Valid (\(timeRemaining))", color: remainingTimeColor)
        }
    }

    private func parseToken(data: Data) -> (remainingTime: Int, expiryDate: Date)? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let expiryString = json["expiry"] as? String {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
                
                if let expiryDate = isoFormatter.date(from: expiryString) {
                    self.expiryDate = expiryDate  // Store immediately
                    let now = Date()
                    let remainingSeconds = expiryDate.timeIntervalSinceNow
                    
                    // Calculate and store minutes and seconds
                    self.remainingMinutes = Int(remainingSeconds) / 60
                    self.remainingSeconds = Int(remainingSeconds) % 60
                    
                    // Store the access token
                    if let accessToken = json["access_token"] as? String {
                        self.accessToken = accessToken
                    }
                    
                    // Debug logging
                    ConsoleManager.shared.log("📅 Token expiry: \(expiryString)", color: .gray)
                    ConsoleManager.shared.log("⏱️ Remaining time: \(self.remainingMinutes) minutes", color: .green)
                    ConsoleManager.shared.log("🔍 Debug: Token expiry = \(expiryDate)", color: .gray)
                    ConsoleManager.shared.log("🔍 Debug: Current time = \(now)", color: .gray)
                    ConsoleManager.shared.log("🔍 Debug: Remaining seconds = \(remainingSeconds)", color: .gray)
                    
                    return (self.remainingMinutes, expiryDate)
                }
            }
        } catch {
            ConsoleManager.shared.log("❌ parseToken error: \(error.localizedDescription)", color: .red)
        }
        return nil
    }
}
