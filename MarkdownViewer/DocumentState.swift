import Combine
import CoreGraphics
import Foundation
import Markdown

class DocumentState: ObservableObject {
    @Published var htmlContent: String = ""
    @Published var title: String = "Markdown Viewer"
    @Published var fileChanged: Bool = false
    @Published var outlineItems: [OutlineItem] = []
    @Published var reloadToken: UUID?
    @Published var zoomLevel: CGFloat = 1.0
    @Published var isShowingFindBar: Bool = false
    @Published var findQuery: String = ""
    @Published var findRequest: FindRequest?
    @Published var findFocusToken: UUID = UUID()
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
            var renderer = MarkdownRenderer()
            let rendered = renderer.render(document)
            let frontMatterHTML = renderFrontMatter(frontMatter)
            htmlContent = wrapInHTML(frontMatterHTML + rendered.html, title: url.lastPathComponent)
            title = url.lastPathComponent
            outlineItems = normalizedOutline(rendered.outline)
        } catch {
            htmlContent = wrapInHTML("<p>Error loading file: \(error.localizedDescription)</p>", title: "Error")
            title = "Error"
            outlineItems = []
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
        <div class=\"front-matter\">
        <table class=\"front-matter-table\">
        """
        for (key, value) in frontMatter {
            let displayKey = key.replacingOccurrences(of: "_", with: " ").capitalized
            html += "<tr><td class=\"fm-key\">\(escapeHTML(displayKey))</td><td class=\"fm-value\">\(escapeHTML(value))</td></tr>\n"
        }
        html += "</table></div>\n"
        return html
    }

    private func normalizedOutline(_ items: [OutlineItem]) -> [OutlineItem] {
        let h1Count = items.filter { $0.level == 1 }.count
        guard h1Count == 1 else { return items }

        return items.compactMap { item in
            if item.level == 1 {
                return nil
            }
            return OutlineItem(title: item.title, level: max(1, item.level - 1), anchorID: item.anchorID)
        }
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
        reloadToken = UUID()
        loadFile(at: url)
    }

    func zoomIn() {
        zoomLevel = min(zoomLevel + 0.1, 3.0)
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel - 0.1, 0.5)
    }

    func resetZoom() {
        zoomLevel = 1.0
    }

    func showFindBar() {
        let wasShowing = isShowingFindBar
        isShowingFindBar = true
        findFocusToken = UUID()
        if !wasShowing {
            updateFindResults()
        }
    }

    func hideFindBar() {
        isShowingFindBar = false
        clearFindHighlights()
    }

    func updateFindResults() {
        requestFind(direction: .forward, reset: true)
    }

    func findNext() {
        requestFind(direction: .forward, reset: false)
    }

    func findPrevious() {
        requestFind(direction: .backward, reset: false)
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

    private func requestFind(direction: FindDirection, reset: Bool) {
        let trimmed = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            findRequest = FindRequest(query: "", direction: .forward, token: UUID(), reset: true)
            return
        }
        findRequest = FindRequest(query: trimmed, direction: direction, token: UUID(), reset: reset)
    }

    private func clearFindHighlights() {
        findRequest = FindRequest(query: "", direction: .forward, token: UUID(), reset: true)
    }

    private func wrapInHTML(_ body: String, title: String) -> String {
        MarkdownHTMLTemplate.shared.render(body: body, title: title)
    }
}
