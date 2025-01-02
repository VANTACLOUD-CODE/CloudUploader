import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowDelegate: AppWindowDelegate?
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize theme manager first
        let themeManager = ThemeManager.shared
        
        // Delay to ensure windows are initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let mainWindow = NSApplication.shared.windows.first {
                self.window = mainWindow
                self.window.title = "Cloud Uploader"
                
                // Add title bar accessory
                let accessoryView = NSHostingView(rootView: ThemeSwitcher())
                let accessoryController = NSTitlebarAccessoryViewController()
                accessoryController.view = accessoryView
                accessoryController.layoutAttribute = .right
                accessoryController.view.frame = NSRect(x: 0, y: 0, width: 40, height: 30)
                self.window.addTitlebarAccessoryViewController(accessoryController)
                
                // Set window appearance
                let appearance = NSAppearance(named: themeManager.isDarkMode ? .darkAqua : .aqua)
                self.window.appearance = appearance
                
                self.windowDelegate = AppWindowDelegate()
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
