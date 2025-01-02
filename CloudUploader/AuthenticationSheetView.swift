import SwiftUI
import WebKit

struct AuthenticationSheetView: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    @Binding var isVisible: Bool // Binding to manage visibility

    var body: some View {
        ZStack {
            // Semi-transparent background to dim the rest of the app and enable click-to-dismiss
            Color.black.opacity(0.69)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    viewModel.dismissAuthSheet()
                    isVisible = false
                }

            // Main container for WebView
            ZStack(alignment: .topTrailing) {
                if let webView = viewModel.webView {
                    WebViewWrapper(webView: webView)
                        .frame(maxWidth: 650, maxHeight: 650) // Define max size for the WebView
                        .cornerRadius(10) // Rounded corners for the WebView
                        .shadow(radius: 10)
                } else {
                    // Loading placeholder
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        Text("🔐 Authentication Loading...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Preparing secure sign-in...")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(width: 650, height: 650) // Reasonable size for placeholder
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(10)
                    .shadow(radius: 10)
                }

                // Close button overlaid on top of WebView
                Button(action: {
                    viewModel.dismissAuthSheet()
                    isVisible = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 25)) // Larger size for visibility
                        .foregroundColor(.gray)
                        .padding(5) // Padding for better touch area
                }
                .buttonStyle(.plain)
            }
            .padding(0) // Space around the WebView
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}
