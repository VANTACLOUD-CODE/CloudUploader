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
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(consoleManager.consoleText.indices, id: \.self) { index in
                            Text(consoleManager.consoleText[index].text)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(consoleManager.consoleText[index].color)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: consoleManager.consoleText.count) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo(consoleManager.consoleText.count - 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        .shadow(radius: 2)
                )
            }
        }
    }
}
