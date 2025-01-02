import SwiftUI
import AppKit

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("isDarkMode") var isDarkMode = false {
        didSet {
            updateAppearance()
        }
    }
    
    init() {
        // Set initial theme based on system
        isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        updateAppearance()
    }
    
    func updateAppearance() {
        let appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        NSApp.appearance = appearance
        
        // Update all windows
        NSApp.windows.forEach { window in
            window.appearance = appearance
        }
        
        // Force UI update
        objectWillChange.send()
    }
}
