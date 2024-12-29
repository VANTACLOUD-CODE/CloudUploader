import Foundation
import SwiftUI

class TokenManager: ObservableObject {
    // MARK: - Published Properties
    @Published var tokenStatus: String = "❌ Token expired"
    @Published var timeRemaining: String = "N/A"
    @Published var remainingTimeColor: Color = .red

    // Show/hide "Authenticate" or "Refresh" buttons
    @Published var showAuthenticateButton: Bool = true
    @Published var showRefreshButton: Bool = false

    // If you want to store the short-lived access token in memory:
    @Published var accessToken: String?

    // Paths or Keychain references
    private let keychain = KeychainHelper.standard

    private let refreshTokenService = "com.CloudUploader.refresh"
    private let refreshTokenAccount = "UserRefreshToken"

    private let tokenFilePath = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"

    // MARK: - Init
    init() {
        checkTokenStatus()
    }

    // MARK: - Check Token
    func checkTokenStatus() {
        // 1) Check if we have a refresh token in Keychain
        guard let refreshToken = loadRefreshToken() else {
            updateTokenStatus(valid: false, remainingTime: "N/A")
            return
        }

        // 2) Check if short-lived token file exists
        guard FileManager.default.fileExists(atPath: tokenFilePath) else {
            // If no short-lived token, we might need to refresh or consider invalid
            updateTokenStatus(valid: false, remainingTime: "N/A")
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: tokenFilePath))
            if let details = parseToken(data: data) {
                let isValid = details.remainingTime > 0
                updateTokenStatus(valid: isValid, remainingTime: "\(details.remainingTime) minutes")
                if isValid {
                    // If you want to store an in-memory access token:
                    accessToken = String(data: data, encoding: .utf8)
                }
            } else {
                updateTokenStatus(valid: false, remainingTime: "Invalid token")
            }
        } catch {
            updateTokenStatus(valid: false, remainingTime: "Failed to parse token")
        }
    }

    // MARK: - Save / Load Refresh Token
    func saveRefreshToken(_ refreshToken: String) {
        if let data = refreshToken.data(using: .utf8) {
            keychain.save(data, service: refreshTokenService, account: refreshTokenAccount)
        }
    }

    func loadRefreshToken() -> String? {
        guard let data = keychain.read(service: refreshTokenService, account: refreshTokenAccount) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Refresh Logic
    func refreshToken() {
        // Example: call a Python script or an HTTP request to get a new short-lived token
        // We'll do a simulation:

        simulateRefresh()
    }

    private func simulateRefresh() {
        // Write a token.json with ~30 mins from now
        let expiryDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(1800))
        let newToken = [
            "expiry": expiryDate,
            "access_token": "FakeAccessToken12345" // etc.
        ]
        if let data = try? JSONSerialization.data(withJSONObject: newToken, options: []) {
            try? data.write(to: URL(fileURLWithPath: tokenFilePath))
        }
        checkTokenStatus()
    }

    // MARK: - Internal Helpers
    private func updateTokenStatus(valid: Bool, remainingTime: String) {
        tokenStatus = valid ? "✅ Token valid" : "❌ Token expired"
        timeRemaining = valid ? remainingTime : "❗️Expired"
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
                    let remaining = Int(expiryDate.timeIntervalSinceNow / 60)
                    return (remainingTime: remaining, expiryDate: expiryDate)
                }
            }
        } catch {
            print("❌ parseToken error: \(error.localizedDescription)")
        }
        return nil
    }
}
