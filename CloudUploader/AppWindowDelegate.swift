import Cocoa
import SwiftUI

class AppWindowDelegate: NSObject, NSWindowDelegate {
    var onCloseAttempt: () -> Void

    init(onCloseAttempt: @escaping () -> Void) {
        self.onCloseAttempt = onCloseAttempt
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCloseAttempt()
        return false // Prevent the window from closing immediately
    }
}