import Foundation
import SwiftUI
import WebKit

private struct FindPayload: Encodable {
    let query: String
    let direction: String
    let reset: Bool
}

struct WebView: NSViewRepresentable {
    let htmlContent: String
    let scrollRequest: ScrollRequest?
    let reloadToken: UUID?
    let zoomLevel: CGFloat
    let findRequest: FindRequest?
    let onActiveAnchorChange: ((String?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onActiveAnchorChange: onActiveAnchorChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "outlinePosition")
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let baseURL = Bundle.module.resourceURL ?? Bundle.main.resourceURL
        if htmlContent != context.coordinator.lastHTML {
            let shouldPreserveScroll = reloadToken != nil && reloadToken != context.coordinator.lastReloadToken
            context.coordinator.lastReloadToken = reloadToken
            context.coordinator.lastHTML = htmlContent
            context.coordinator.isLoading = true
            context.coordinator.lastActiveAnchorID = nil

            if shouldPreserveScroll {
                let coordinator = context.coordinator
                webView.evaluateJavaScript("window.scrollY") { result, _ in
                    coordinator.savedScrollY = (result as? CGFloat) ?? 0
                    webView.loadHTMLString(htmlContent, baseURL: baseURL)
                }
            } else {
                webView.loadHTMLString(htmlContent, baseURL: baseURL)
            }
        }

        if let request = scrollRequest {
            context.coordinator.requestScroll(request, in: webView)
        }

        if zoomLevel != context.coordinator.lastZoomLevel {
            context.coordinator.lastZoomLevel = zoomLevel
            let percentage = Int(zoomLevel * 100)
            webView.evaluateJavaScript("document.body.style.zoom = '\(percentage)%'", completionHandler: nil)
        }

        if let request = findRequest {
            context.coordinator.requestFind(request, in: webView)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastHTML: String?
        var pendingAnchor: String?
        var pendingToken: UUID?
        var lastHandledToken: UUID?
        var isLoading = false
        var lastReloadToken: UUID?
        var savedScrollY: CGFloat = 0
        var lastZoomLevel: CGFloat = 1.0
        var pendingFindRequest: FindRequest?
        var lastFindToken: UUID?
        var lastActiveAnchorID: String?
        private let onActiveAnchorChange: ((String?) -> Void)?

        init(onActiveAnchorChange: ((String?) -> Void)?) {
            self.onActiveAnchorChange = onActiveAnchorChange
        }

        func requestScroll(_ request: ScrollRequest, in webView: WKWebView) {
            guard request.token != lastHandledToken else { return }
            pendingAnchor = request.id
            pendingToken = request.token
            if !isLoading {
                performScroll(in: webView)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false

            if lastZoomLevel != 1.0 {
                let percentage = Int(lastZoomLevel * 100)
                webView.evaluateJavaScript("document.body.style.zoom = '\(percentage)%'", completionHandler: nil)
            }

            if savedScrollY > 0 {
                let scrollY = savedScrollY
                savedScrollY = 0
                webView.evaluateJavaScript("window.scrollTo(0, \(scrollY))", completionHandler: nil)
            }

            performScroll(in: webView)
            performFind(in: webView)
        }

        private func performScroll(in webView: WKWebView) {
            guard let anchor = pendingAnchor, let token = pendingToken else { return }
            pendingAnchor = nil
            pendingToken = nil
            lastHandledToken = token

            let escaped = anchor
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let script = "var el = document.getElementById('\(escaped)'); if (el) { el.scrollIntoView(); }"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        func requestFind(_ request: FindRequest, in webView: WKWebView) {
            guard request.token != lastFindToken else { return }
            lastFindToken = request.token
            pendingFindRequest = request
            if !isLoading {
                performFind(in: webView)
            }
        }

        private func performFind(in webView: WKWebView) {
            guard let request = pendingFindRequest else { return }
            pendingFindRequest = nil
            let payload = FindPayload(
                query: request.query,
                direction: request.direction == .backward ? "backward" : "forward",
                reset: request.reset
            )
            guard let data = try? JSONEncoder().encode(payload),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }
            webView.evaluateJavaScript("window.__markdownViewerFind(\(json));", completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "outlinePosition" else { return }
            var anchorID: String?
            if let body = message.body as? [String: Any] {
                anchorID = body["id"] as? String
            } else if let body = message.body as? String {
                anchorID = body
            }
            if anchorID?.isEmpty == true {
                anchorID = nil
            }
            guard anchorID != lastActiveAnchorID else { return }
            lastActiveAnchorID = anchorID
            DispatchQueue.main.async { [onActiveAnchorChange] in
                onActiveAnchorChange?(anchorID)
            }
        }
    }
}
