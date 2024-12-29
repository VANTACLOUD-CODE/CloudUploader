import SwiftUI
import WebKit

struct WebViewWrapper: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        // We simply return the same webView we were given
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // If needed, update the WKWebView in response to state changes
    }
}
