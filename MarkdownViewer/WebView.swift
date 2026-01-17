import SwiftUI
import WebKit

struct ScrollRequest: Equatable {
    let id: String
    let token: UUID
}

enum FindDirection: Equatable {
    case forward
    case backward
}

struct FindRequest: Equatable {
    let query: String
    let direction: FindDirection
    let token: UUID
    let reset: Bool
}

struct FindPayload: Encodable {
    let query: String
    let direction: String
    let reset: Bool
}

struct CommentSelection: Equatable {
    let start: Int
    let end: Int
    let text: String
    let rect: CGRect
}

struct WebView: NSViewRepresentable {
    let htmlContent: String
    let scrollRequest: ScrollRequest?
    let reloadToken: UUID?
    let zoomLevel: CGFloat
    let findRequest: FindRequest?
    let commentSelectionRequest: UUID?
    let onAddComment: (CommentSelection, String) -> Void
    let onUpdateComment: (String, String) -> Void
    let onDeleteComment: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "commentAdd")
        userContentController.add(context.coordinator, name: "commentUpdate")
        userContentController.add(context.coordinator, name: "commentDelete")
        config.userContentController = userContentController
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAddComment = onAddComment
        context.coordinator.onUpdateComment = onUpdateComment
        context.coordinator.onDeleteComment = onDeleteComment

        if htmlContent != context.coordinator.lastHTML {
            let shouldPreserveScroll = reloadToken != nil && reloadToken != context.coordinator.lastReloadToken
            context.coordinator.lastReloadToken = reloadToken
            context.coordinator.lastHTML = htmlContent
            context.coordinator.isLoading = true

            if shouldPreserveScroll {
                let coordinator = context.coordinator
                webView.evaluateJavaScript("window.scrollY") { result, _ in
                    coordinator.savedScrollY = (result as? CGFloat) ?? 0
                    webView.loadHTMLString(htmlContent, baseURL: nil)
                }
            } else {
                webView.loadHTMLString(htmlContent, baseURL: nil)
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

        if let request = commentSelectionRequest,
           request != context.coordinator.lastCommentSelectionRequest {
            context.coordinator.lastCommentSelectionRequest = request
            context.coordinator.requestCommentSelection(in: webView)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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
        var lastCommentSelectionRequest: UUID?
        var onAddComment: ((CommentSelection, String) -> Void)?
        var onUpdateComment: ((String, String) -> Void)?
        var onDeleteComment: ((String) -> Void)?

        func requestScroll(_ request: ScrollRequest, in webView: WKWebView) {
            guard request.token != lastHandledToken else { return }
            pendingAnchor = request.id
            pendingToken = request.token
            if !isLoading {
                performScroll(in: webView)
            }
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

        func requestCommentSelection(in webView: WKWebView) {
            let script = "window.__markdownViewerCommentUI && window.__markdownViewerCommentUI.openFromSelection ? window.__markdownViewerCommentUI.openFromSelection() : null"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            switch message.name {
            case "commentAdd":
                guard let start = body["start"] as? Double,
                      let end = body["end"] as? Double,
                      let comment = body["body"] as? String else {
                    return
                }
                let selection = CommentSelection(start: Int(start), end: Int(end), text: "", rect: .zero)
                onAddComment?(selection, comment)
            case "commentUpdate":
                guard let id = body["id"] as? String,
                      let comment = body["body"] as? String else {
                    return
                }
                onUpdateComment?(id, comment)
            case "commentDelete":
                guard let id = body["id"] as? String else {
                    return
                }
                onDeleteComment?(id)
            default:
                return
            }
        }
    }
}
