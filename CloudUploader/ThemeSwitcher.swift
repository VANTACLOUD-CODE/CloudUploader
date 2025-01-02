import SwiftUI
import AppKit

struct ThemeSwitcher: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            Spacer()
            Menu {
                Text("Appearance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                
                Divider()
                
                Button(action: {
                    withAnimation {
                        themeManager.isDarkMode = false
                    }
                }) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                        Text("Light")
                        Spacer()
                        if !themeManager.isDarkMode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        themeManager.isDarkMode = true
                    }
                }) {
                    HStack {
                        Image(systemName: "moon.fill")
                        Text("Dark")
                        Spacer()
                        if themeManager.isDarkMode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .frame(width: 30, height: 30)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 30, height: 30)
            Spacer()
        }
        .frame(width: 40)
    }
}
