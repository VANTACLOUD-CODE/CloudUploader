import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowDelegate: AppWindowDelegate?
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Delay to ensure windows are initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let mainWindow = NSApplication.shared.windows.first {
                self.window = mainWindow
                self.windowDelegate = AppWindowDelegate {
                    // Trigger quit confirmation via shared ViewModel
                    CloudUploaderViewModel.shared.showQuitConfirmation = true
                }
                self.window.delegate = self.windowDelegate
            }
        }
    }

    // If you're handling URL opens, retain existing implementation or remove if unused
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Handle both localhost and custom scheme
        if url.host == "localhost" || (url.scheme == "clouduploader" && url.host == "oauth-callback") {
            if let code = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first(where: { $0.name == "code" })?.value {
                CloudUploaderViewModel.shared.handleAuthCode(code)
            }
        }
    }
}