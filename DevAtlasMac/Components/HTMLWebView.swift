import SwiftUI
import WebKit

/// A SwiftUI wrapper for WKWebView to display HTML content
struct HTMLWebView: NSViewRepresentable {
    let htmlContent: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // Transparent background
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
