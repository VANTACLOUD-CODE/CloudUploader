import SwiftUI
import WebKit

struct AuthenticationSheetView: View {
    @ObservedObject var viewModel: CloudUploaderViewModel
    @Binding var isVisible: Bool // Binding to manage visibility

    var body: some View {
        ZStack {
            // Semi-transparent background to dim the rest of the app and enable click-to-dismiss
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Dismiss the overlay when tapping outside
                    isVisible = false
                }

            // Main container for WebView
            ZStack(alignment: .topTrailing) {
                if let webView = viewModel.webView {
                    WebViewWrapper(webView: webView)
                        .frame(maxWidth: 550, maxHeight: 750) // Define max size for the WebView
                        .cornerRadius(10) // Rounded corners for the WebView
                        .shadow(radius: 10)
                } else {
                    // Loading placeholder
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("🔐 Loading Authentication...")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 550, height: 750) // Reasonable size for placeholder
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(10)
                    .shadow(radius: 10)
                }

                // Close button overlaid on top of WebView
                Button(action: {
                    // Dismiss the overlay
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
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}
