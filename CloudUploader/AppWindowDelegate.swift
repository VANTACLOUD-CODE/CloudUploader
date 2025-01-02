import Cocoa
import SwiftUI

@MainActor
class AppWindowDelegate: NSObject, NSWindowDelegate, ObservableObject {
    @Published var quitHandler = QuitConfirmationHandler.shared
    
    override init() {
        super.init()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let viewModel = CloudUploaderViewModel.shared
        if viewModel.isMonitoring {
            withAnimation(.easeInOut(duration: 0.3)) {
                quitHandler.showQuitConfirmation = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                quitHandler.showQuitConfirmation = true
            }
        }
        return false
    }
}