import SwiftUI

@MainActor
class QuitConfirmationHandler: ObservableObject {
    static let shared = QuitConfirmationHandler()
    
    @Published var showQuitConfirmation: Bool = false
    
    func handleQuitAttempt() -> Bool {
        withAnimation(.easeInOut(duration: 0.3)) {
            showQuitConfirmation = true
        }
        return false
    }
    
    func confirmQuit() {
        NSApplication.shared.terminate(nil)
    }
    
    func cancelQuit() {
        withAnimation {
            showQuitConfirmation = false
        }
    }
}
