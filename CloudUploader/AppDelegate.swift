import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: CloudUploaderViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize ViewModel
        viewModel = CloudUploaderViewModel()
    }
    
    // This method is no longer used as redirects are handled by the LocalServer
    func application(_ application: NSApplication, open urls: [URL]) {
        // No implementation needed
    }
}
