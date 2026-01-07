import SwiftUI
import Markdown
import WebKit
import ObjectiveC

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recentFilesStore = RecentFilesStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    appDelegate.openFileFromPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    ForEach(recentFilesStore.recentFiles, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            appDelegate.openFile(at: url)
                        }
                    }
                    if !recentFilesStore.recentFiles.isEmpty {
                        Divider()
                        Button("Clear Menu") {
                            recentFilesStore.clear()
                        }
                    }
                }
            }
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appDelegate.openEmptyTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Reload") {
                    appDelegate.reloadActiveDocument()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [ViewerWindowController] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openFile(at: url)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func openFileFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            openFile(at: url)
        }
    }

    func openFile(at url: URL) {
        if let documentState = reusableEmptyDocumentState() {
            documentState.loadFile(at: url)
            focusWindow(for: documentState)
            return
        }

        openInNewTab(url: url)
    }

    func openEmptyTab() {
        openInNewTab(url: nil)
    }

    func reloadActiveDocument() {
        activeDocumentState()?.reload()
    }

    private func activeDocumentState() -> DocumentState? {
        if let state = NSApplication.shared.keyWindow?.documentState {
            return state
        }
        if let state = NSApplication.shared.mainWindow?.documentState {
            return state
        }
        return NSApplication.shared.windows.compactMap(\.documentState).first
    }

    private func reusableEmptyDocumentState() -> DocumentState? {
        if let active = activeDocumentState(), active.currentURL == nil {
            return active
        }
        return NSApplication.shared.windows
            .compactMap(\.documentState)
            .first { $0.currentURL == nil }
    }

    private func focusWindow(for documentState: DocumentState) {
        if let window = NSApplication.shared.windows.first(where: { $0.documentState === documentState }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func openInNewTab(url: URL?) {
        let documentState = DocumentState()
        if let url {
            documentState.loadFile(at: url)
        }

        openWindow(with: documentState)
    }

    private func openWindow(with documentState: DocumentState) {
        let contentView = ContentView(documentState: documentState)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 600, height: 400))
        window.tabbingMode = .preferred
        window.title = documentState.title
        window.documentState = documentState

        let windowController = ViewerWindowController(window: window)
        window.delegate = windowController
        windowController.onClose = { [weak self, weak windowController] in
            guard let windowController else { return }
            self?.windowControllers.removeAll { $0 === windowController }
        }
        if let tabGroupWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            tabGroupWindow.addTabbedWindow(window, ordered: .above)
        }
        windowController.showWindow(nil)
        windowControllers.append(windowController)
    }
}

final class ViewerWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

private var documentStateKey: UInt8 = 0

private extension NSWindow {
    var documentState: DocumentState? {
        get {
            objc_getAssociatedObject(self, &documentStateKey) as? DocumentState
        }
        set {
            objc_setAssociatedObject(self, &documentStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

final class RecentFilesStore: ObservableObject {
    static let shared = RecentFilesStore()

    @Published private(set) var recentFiles: [URL] = []
    private let maxRecentFiles = 10
    private let defaultsKey = "recentFiles"

    private init() {
        load()
    }

    func add(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        save()
    }

    func clear() {
        recentFiles = []
        save()
    }

    private func save() {
        let paths = recentFiles.map { $0.path }
        UserDefaults.standard.set(paths, forKey: defaultsKey)
    }

    private func load() {
        if let paths = UserDefaults.standard.stringArray(forKey: defaultsKey) {
            recentFiles = paths.compactMap { URL(fileURLWithPath: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }
}

class DocumentState: ObservableObject {
    @Published var htmlContent: String = ""
    @Published var title: String = "Markdown Viewer"
    @Published var fileChanged: Bool = false
    var currentURL: URL?
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var lastModificationDate: Date?
    private let recentFilesStore: RecentFilesStore

    init(recentFilesStore: RecentFilesStore = .shared) {
        self.recentFilesStore = recentFilesStore
    }

    deinit {
        stopMonitoring()
    }

    func loadFile(at url: URL) {
        currentURL = url
        fileChanged = false
        startMonitoring(url: url)
        recentFilesStore.add(url)
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            let (frontMatter, content) = parseFrontMatter(markdown)
            let document = Document(parsing: content)
            var htmlVisitor = HTMLConverter()
            let html = htmlVisitor.visit(document)
            let frontMatterHTML = renderFrontMatter(frontMatter)
            self.htmlContent = wrapInHTML(frontMatterHTML + html, title: url.lastPathComponent)
            self.title = url.lastPathComponent
        } catch {
            self.htmlContent = wrapInHTML("<p>Error loading file: \(error.localizedDescription)</p>", title: "Error")
            self.title = "Error"
        }
    }

    private func parseFrontMatter(_ markdown: String) -> ([(String, String)], String) {
        let lines = markdown.components(separatedBy: "\n")
        guard lines.first == "---" else { return ([], markdown) }

        var frontMatter: [(String, String)] = []
        var endIndex = 0

        for (index, line) in lines.dropFirst().enumerated() {
            if line == "---" {
                endIndex = index + 2
                break
            }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    frontMatter.append((key, value))
                }
            }
        }

        let content = lines.dropFirst(endIndex).joined(separator: "\n")
        return (frontMatter, content)
    }

    private func renderFrontMatter(_ frontMatter: [(String, String)]) -> String {
        guard !frontMatter.isEmpty else { return "" }

        var html = """
        <div class="front-matter">
        <table class="front-matter-table">
        """
        for (key, value) in frontMatter {
            let displayKey = key.replacingOccurrences(of: "_", with: " ").capitalized
            html += "<tr><td class=\"fm-key\">\(escapeHTML(displayKey))</td><td class=\"fm-value\">\(escapeHTML(value))</td></tr>\n"
        }
        html += "</table></div>\n"
        return html
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    func reload() {
        guard let url = currentURL else { return }
        loadFile(at: url)
    }

    private func startMonitoring(url: URL) {
        stopMonitoring()

        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        lastModificationDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date

        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        fileMonitor?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let newModDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
            if newModDate != self.lastModificationDate {
                self.fileChanged = true
            }
        }

        fileMonitor?.setCancelHandler {
            close(fileDescriptor)
        }

        fileMonitor?.resume()
    }

    private func stopMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    private func wrapInHTML(_ body: String, title: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
            <style>
                :root {
                    color-scheme: light dark;
                    --color-fg-default: #1f2328;
                    --color-fg-muted: #656d76;
                    --color-canvas-default: #ffffff;
                    --color-canvas-subtle: #f6f8fa;
                    --color-border-default: #d0d7de;
                    --color-border-muted: hsla(210,18%,87%,1);
                    --color-accent-fg: #0969da;
                    --color-danger-fg: #d1242f;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --color-fg-default: #e6edf3;
                        --color-fg-muted: #8d96a0;
                        --color-canvas-default: #0d1117;
                        --color-canvas-subtle: #161b22;
                        --color-border-default: #30363d;
                        --color-border-muted: #21262d;
                        --color-accent-fg: #4493f8;
                        --color-danger-fg: #f85149;
                    }
                }
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    word-wrap: break-word;
                    max-width: 980px;
                    margin: 0 auto;
                    padding: 32px 28px;
                    background-color: var(--color-canvas-default);
                    color: var(--color-fg-default);
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid var(--color-border-muted); }
                h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid var(--color-border-muted); }
                h3 { font-size: 1.25em; }
                h4 { font-size: 1em; }
                h5 { font-size: 0.875em; }
                h6 { font-size: 0.85em; color: var(--color-fg-muted); }
                p { margin-top: 0; margin-bottom: 10px; }
                a {
                    color: var(--color-accent-fg);
                    text-decoration: none;
                }
                a:hover { text-decoration: underline; }
                code {
                    font-family: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace;
                    font-size: 85%;
                    padding: 0.2em 0.4em;
                    margin: 0;
                    background-color: var(--color-canvas-subtle);
                    border-radius: 6px;
                }
                pre {
                    margin-top: 0;
                    margin-bottom: 16px;
                    padding: 16px;
                    overflow: auto;
                    font-size: 85%;
                    line-height: 1.45;
                    background-color: var(--color-canvas-subtle);
                    border-radius: 6px;
                }
                pre code {
                    display: block;
                    padding: 0;
                    margin: 0;
                    overflow: visible;
                    line-height: inherit;
                    word-wrap: normal;
                    background-color: transparent;
                    border: 0;
                    font-size: 100%;
                }
                blockquote {
                    margin: 0 0 16px 0;
                    padding: 0 1em;
                    color: var(--color-fg-muted);
                    border-left: 0.25em solid var(--color-border-default);
                }
                blockquote > :first-child { margin-top: 0; }
                blockquote > :last-child { margin-bottom: 0; }
                ul, ol {
                    margin-top: 0;
                    margin-bottom: 16px;
                    padding-left: 2em;
                }
                li { margin-top: 0.25em; }
                li + li { margin-top: 0.25em; }
                ul ul, ul ol, ol ol, ol ul {
                    margin-top: 0;
                    margin-bottom: 0;
                }
                hr {
                    height: 0.25em;
                    padding: 0;
                    margin: 24px 0;
                    background-color: var(--color-border-default);
                    border: 0;
                }
                table {
                    border-spacing: 0;
                    border-collapse: collapse;
                    margin-top: 0;
                    margin-bottom: 16px;
                    display: block;
                    width: max-content;
                    max-width: 100%;
                    overflow: auto;
                }
                table th {
                    font-weight: 600;
                }
                table th, table td {
                    padding: 6px 13px;
                    border: 1px solid var(--color-border-default);
                }
                table tr {
                    background-color: var(--color-canvas-default);
                    border-top: 1px solid var(--color-border-muted);
                }
                table tr:nth-child(2n) {
                    background-color: var(--color-canvas-subtle);
                }
                img {
                    max-width: 100%;
                    box-sizing: content-box;
                    background-color: var(--color-canvas-default);
                }
                del { color: var(--color-fg-muted); }
                strong { font-weight: 600; }
                em { font-style: italic; }
                .front-matter {
                    margin-bottom: 24px;
                    padding: 12px 16px;
                    background-color: var(--color-canvas-subtle);
                    border-radius: 6px;
                    border: 1px solid var(--color-border-muted);
                }
                .front-matter-table {
                    display: table;
                    width: auto;
                    margin: 0;
                    font-size: 12px;
                    border: none;
                }
                .front-matter-table tr {
                    background: transparent !important;
                    border: none;
                }
                .front-matter-table td {
                    padding: 2px 0;
                    border: none;
                    vertical-align: top;
                }
                .front-matter-table .fm-key {
                    color: var(--color-fg-muted);
                    padding-right: 12px;
                    white-space: nowrap;
                    font-weight: 500;
                }
                .front-matter-table .fm-value {
                    color: var(--color-fg-default);
                    font-family: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, monospace;
                }
            </style>
        </head>
        <body>
            \(body)
            <script>hljs.highlightAll();</script>
        </body>
        </html>
        """
    }
}

struct HTMLConverter: MarkupWalker {
    var result = ""

    mutating func visit(_ document: Document) -> String {
        result = ""
        for child in document.children {
            visit(child)
        }
        return result
    }

    mutating func visit(_ markup: any Markup) {
        switch markup {
        case let heading as Heading:
            result += "<h\(heading.level)>"
            for child in heading.children { visit(child) }
            result += "</h\(heading.level)>\n"
        case let paragraph as Paragraph:
            result += "<p>"
            for child in paragraph.children { visit(child) }
            result += "</p>\n"
        case let text as Markdown.Text:
            result += escapeHTML(text.string)
        case let emphasis as Emphasis:
            result += "<em>"
            for child in emphasis.children { visit(child) }
            result += "</em>"
        case let strong as Strong:
            result += "<strong>"
            for child in strong.children { visit(child) }
            result += "</strong>"
        case let code as InlineCode:
            result += "<code>\(escapeHTML(code.code))</code>"
        case let codeBlock as CodeBlock:
            let lang = codeBlock.language ?? ""
            result += "<pre><code class=\"language-\(lang)\">\(escapeHTML(codeBlock.code))</code></pre>\n"
        case let link as Markdown.Link:
            result += "<a href=\"\(link.destination ?? "")\">"
            for child in link.children { visit(child) }
            result += "</a>"
        case let image as Markdown.Image:
            let alt = image.plainText
            result += "<img src=\"\(image.source ?? "")\" alt=\"\(escapeHTML(alt))\">"
        case let list as UnorderedList:
            result += "<ul>\n"
            for child in list.children { visit(child) }
            result += "</ul>\n"
        case let list as OrderedList:
            result += "<ol>\n"
            for child in list.children { visit(child) }
            result += "</ol>\n"
        case let item as ListItem:
            result += "<li>"
            for child in item.children { visit(child) }
            result += "</li>\n"
        case let quote as BlockQuote:
            result += "<blockquote>\n"
            for child in quote.children { visit(child) }
            result += "</blockquote>\n"
        case is ThematicBreak:
            result += "<hr>\n"
        case is SoftBreak:
            result += " "
        case is LineBreak:
            result += "<br>\n"
        case let table as Markdown.Table:
            result += "<table>\n"
            let head = table.head
            result += "<thead><tr>\n"
            for cell in head.cells {
                result += "<th>"
                for child in cell.children { visit(child) }
                result += "</th>\n"
            }
            result += "</tr></thead>\n"
            result += "<tbody>\n"
            for row in table.body.rows {
                result += "<tr>\n"
                for cell in row.cells {
                    result += "<td>"
                    for child in cell.children { visit(child) }
                    result += "</td>\n"
                }
                result += "</tr>\n"
            }
            result += "</tbody></table>\n"
        case let strikethrough as Strikethrough:
            result += "<del>"
            for child in strikethrough.children { visit(child) }
            result += "</del>"
        default:
            for child in markup.children {
                visit(child)
            }
        }
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowResolverView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            onResolve(window)
        }
    }
}

final class WindowResolverView: NSView {
    var onResolve: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onResolve?(window)
        }
    }
}

struct ContentView: View {
    @StateObject private var documentState: DocumentState

    init(documentState: DocumentState = DocumentState()) {
        _documentState = StateObject(wrappedValue: documentState)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if documentState.htmlContent.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Open a Markdown file")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Use File > Open or press \u{2318}O")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WebView(htmlContent: documentState.htmlContent)
                }
            }

            if documentState.fileChanged {
                Button(action: {
                    documentState.reload()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                        Text("File changed")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle(documentState.title)
        .background(WindowAccessor { window in
            window.tabbingMode = .preferred
            window.documentState = documentState
        })
    }
}

struct WebView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
