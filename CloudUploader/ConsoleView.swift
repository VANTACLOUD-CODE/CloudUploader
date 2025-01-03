import SwiftUI

struct ConsoleView: View {
    @ObservedObject var consoleManager: ConsoleManager
    
    var body: some View {
        VStack {
            Text("☁️ Uploader Console")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
            
            ScrollViewReader { proxy in
                ScrollView {
                    Text(formattedConsoleText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .id("bottom")
                }
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .shadow(radius: 2)
                )
                .onChange(of: consoleManager.consoleText.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var formattedConsoleText: AttributedString {
        var result = AttributedString("")
        for (index, message) in consoleManager.consoleText.enumerated() {
            var line = AttributedString(message.text)
            line.foregroundColor = message.color
            result += line
            if index < consoleManager.consoleText.count - 1 {
                result += AttributedString("\n")
            }
        }
        return result
    }
}
