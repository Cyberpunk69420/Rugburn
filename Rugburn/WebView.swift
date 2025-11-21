import SwiftUI
import WebKit

struct MacWebView: NSViewRepresentable {
    let url: URL
    @Binding var loadError: String?
    var userAgent: String? = nil

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: config)
        if let ua = userAgent {
            web.customUserAgent = ua
        }
        web.navigationDelegate = context.coordinator
        Logger.log("Creating WKWebView for URL: \(url) with UA: \(userAgent ?? "default")")
        return web
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.customUserAgent != userAgent {
            webView.customUserAgent = userAgent
        }
        Logger.log("Loading URL in WKWebView: \(url) with UA: \(userAgent ?? "default")")
        let request = URLRequest(url: url)
        webView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MacWebView
        init(_ parent: MacWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Logger.log("WebView started navigation: \(parent.url)")
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.log("WebView finished navigation: \(parent.url)")
            parent.loadError = nil
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Logger.log("WebView navigation failed: \(error.localizedDescription)", level: .error)
            parent.loadError = error.localizedDescription
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Logger.log("WebView provisional navigation failed: \(error.localizedDescription)", level: .error)
            parent.loadError = error.localizedDescription
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Logger.log("WebView content process terminated", level: .error)
        }
    }
}
