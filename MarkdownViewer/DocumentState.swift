import Markdown
import SwiftUI

enum CommentConstants {
    static let headerPrefix = "<!-- MarkdownViewer comments:"
    static let headerLine = "<!-- MarkdownViewer comments: Do not remove MV-COMMENT markers. They anchor inline comments. -->"
}

struct OutlineItem: Identifiable {
    let id = UUID()
    let title: String
    let level: Int
    let anchorID: String
}

struct FrontMatterInfo {
    let items: [(String, String)]
    let content: String
    let contentStartOffset: Int
    let frontMatterEndOffset: Int
}

struct MarkdownComment: Identifiable, Equatable {
    let id: String
    let created: Date
    let updated: Date
    let body: String

    var numericID: Int {
        let parts = id.split(separator: "-")
        if parts.count == 2, let number = Int(parts[1]) {
            return number
        }
        return 0
    }
}

struct CommentPayload: Codable {
    let id: String
    let created: String
    let updated: String
    let bodyB64: String
}

enum CommentCodec {
    static func encode(comment: MarkdownComment) -> String? {
        let formatter = ISO8601DateFormatter()
        let payload = CommentPayload(
            id: comment.id,
            created: formatter.string(from: comment.created),
            updated: formatter.string(from: comment.updated),
            bodyB64: Data(comment.body.utf8).base64EncodedString()
        )
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(json: String) -> MarkdownComment? {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(CommentPayload.self, from: data) else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        guard let created = formatter.date(from: payload.created),
              let updated = formatter.date(from: payload.updated),
              let bodyData = Data(base64Encoded: payload.bodyB64),
              let body = String(data: bodyData, encoding: .utf8) else {
            return nil
        }
        return MarkdownComment(id: payload.id, created: created, updated: updated, body: body)
    }
}

final class DocumentState: ObservableObject {
    @Published var htmlContent: String = ""
    @Published var title: String = "Markdown Viewer"
    @Published var fileChanged: Bool = false
    @Published var outlineItems: [OutlineItem] = []
    @Published var comments: [MarkdownComment] = []
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
    private var markdownSource: String = ""

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
            let frontMatterInfo = parseFrontMatter(markdown)
            let content = frontMatterInfo.content
            let document = Document(parsing: content)
            var renderer = MarkdownRenderer(source: content, sourceOffsetBase: frontMatterInfo.contentStartOffset)
            let rendered = renderer.render(document)
            let frontMatterHTML = renderFrontMatter(frontMatterInfo.items)
            htmlContent = HTMLTemplate.wrap(body: frontMatterHTML + rendered.html, title: url.lastPathComponent)
            title = url.lastPathComponent
            outlineItems = normalizedOutline(rendered.outline)
            comments = parseComments(from: markdown)
            markdownSource = markdown
        } catch {
            htmlContent = HTMLTemplate.wrap(body: "<p>Error loading file: \(error.localizedDescription)</p>", title: "Error")
            title = "Error"
            outlineItems = []
            comments = []
            markdownSource = ""
        }
    }

    private func parseFrontMatter(_ markdown: String) -> FrontMatterInfo {
        let lines = markdown.components(separatedBy: "\n")
        guard lines.first == "---" else {
            return FrontMatterInfo(items: [], content: markdown, contentStartOffset: 0, frontMatterEndOffset: 0)
        }

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
        let contentStartIndex = contentStartIndex(in: markdown, endIndex: endIndex)
        let contentStartOffset = markdown.utf8.distance(from: markdown.utf8.startIndex, to: contentStartIndex)
        return FrontMatterInfo(
            items: frontMatter,
            content: content,
            contentStartOffset: contentStartOffset,
            frontMatterEndOffset: contentStartOffset
        )
    }

    private func contentStartIndex(in markdown: String, endIndex: Int) -> String.Index {
        guard endIndex > 0 else { return markdown.startIndex }
        var index = markdown.startIndex
        var linesToSkip = endIndex
        while linesToSkip > 0, index < markdown.endIndex {
            guard let newlineIndex = markdown[index...].firstIndex(of: "\n") else {
                return markdown.endIndex
            }
            index = markdown.index(after: newlineIndex)
            linesToSkip -= 1
        }
        return index
    }

    private func renderFrontMatter(_ frontMatter: [(String, String)]) -> String {
        guard !frontMatter.isEmpty else { return "" }

        var html = """
        <div class="front-matter" data-mv-frontmatter="true">
        <table class="front-matter-table">
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

    func addComment(startOffset: Int, endOffset: Int, body: String) {
        guard let url = currentURL else { return }
        guard startOffset < endOffset else { return }
        do {
            var markdown = try String(contentsOf: url, encoding: .utf8)
            let frontMatterInfo = parseFrontMatter(markdown)
            let headerResult = ensureCommentHeader(in: markdown, insertionOffset: frontMatterInfo.frontMatterEndOffset)
            markdown = headerResult.markdown

            var adjustedStart = startOffset
            var adjustedEnd = endOffset
            if headerResult.insertedBytes > 0 {
                if startOffset >= headerResult.insertionOffset {
                    adjustedStart += headerResult.insertedBytes
                }
                if endOffset >= headerResult.insertionOffset {
                    adjustedEnd += headerResult.insertedBytes
                }
            }

            let existingComments = parseComments(from: markdown)
            let newID = nextCommentID(from: existingComments)
            let now = Date()
            let comment = MarkdownComment(id: newID, created: now, updated: now, body: body)

            guard let updatedMarkdown = insertCommentMarkers(
                in: markdown,
                startOffset: adjustedStart,
                endOffset: adjustedEnd,
                comment: comment
            ) else {
                return
            }
            try updatedMarkdown.write(to: url, atomically: true, encoding: .utf8)
            loadFile(at: url)
        } catch {
            return
        }
    }

    func updateComment(id: String, body: String) {
        guard let url = currentURL else { return }
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            guard let updatedMarkdown = updatingCommentPayload(in: markdown, id: id, body: body) else {
                return
            }
            try updatedMarkdown.write(to: url, atomically: true, encoding: .utf8)
            loadFile(at: url)
        } catch {
            return
        }
    }

    func deleteComment(id: String) {
        guard let url = currentURL else { return }
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            guard let updatedMarkdown = removingCommentMarkers(in: markdown, id: id) else {
                return
            }
            try updatedMarkdown.write(to: url, atomically: true, encoding: .utf8)
            loadFile(at: url)
        } catch {
            return
        }
    }

    private func parseComments(from markdown: String) -> [MarkdownComment] {
        let pattern = "<!--\\s*MV-COMMENT-START\\s+({.*?})\\s*-->"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        let matches = regex.matches(in: markdown, options: [], range: range)
        var comments: [MarkdownComment] = []

        for match in matches {
            guard match.numberOfRanges > 1,
                  let jsonRange = Range(match.range(at: 1), in: markdown) else {
                continue
            }
            let json = String(markdown[jsonRange])
            if let comment = CommentCodec.decode(json: json) {
                comments.append(comment)
            }
        }

        return comments.sorted { $0.numericID < $1.numericID }
    }

    private func nextCommentID(from comments: [MarkdownComment]) -> String {
        let maxID = comments.map(\.numericID).max() ?? 0
        return "COM-\(maxID + 1)"
    }

    private func ensureCommentHeader(in markdown: String, insertionOffset: Int) -> (markdown: String, insertedBytes: Int, insertionOffset: Int) {
        if markdown.contains(CommentConstants.headerPrefix) {
            return (markdown, 0, insertionOffset)
        }
        let header = CommentConstants.headerLine + "\n\n"
        guard let insertIndex = indexForUTF8Offset(insertionOffset, in: markdown) else {
            return (markdown, 0, insertionOffset)
        }
        let updated = String(markdown[..<insertIndex]) + header + String(markdown[insertIndex...])
        return (updated, header.utf8.count, insertionOffset)
    }

    private func insertCommentMarkers(in markdown: String, startOffset: Int, endOffset: Int, comment: MarkdownComment) -> String? {
        guard let startIndex = indexForUTF8Offset(startOffset, in: markdown),
              let endIndex = indexForUTF8Offset(endOffset, in: markdown),
              startIndex <= endIndex,
              let payload = CommentCodec.encode(comment: comment) else {
            return nil
        }
        let startMarker = "<!-- MV-COMMENT-START \(payload) -->"
        let endMarker = "<!-- MV-COMMENT-END \(comment.id) -->"
        let before = markdown[..<startIndex]
        let middle = markdown[startIndex..<endIndex]
        let after = markdown[endIndex...]
        return String(before) + startMarker + String(middle) + endMarker + String(after)
    }

    private func updatingCommentPayload(in markdown: String, id: String, body: String) -> String? {
        let pattern = "<!--\\s*MV-COMMENT-START\\s+({.*?})\\s*-->"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        let matches = regex.matches(in: markdown, options: [], range: range)
        let mutable = NSMutableString(string: markdown)

        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let jsonRange = match.range(at: 1)
            let json = (markdown as NSString).substring(with: jsonRange)
            guard let existing = CommentCodec.decode(json: json), existing.id == id else {
                continue
            }
            let updated = MarkdownComment(id: existing.id, created: existing.created, updated: Date(), body: body)
            guard let payload = CommentCodec.encode(comment: updated) else { continue }
            let replacement = "<!-- MV-COMMENT-START \(payload) -->"
            mutable.replaceCharacters(in: match.range, with: replacement)
            return mutable as String
        }
        return nil
    }

    private func removingCommentMarkers(in markdown: String, id: String) -> String? {
        let startPattern = "<!--\\s*MV-COMMENT-START\\s+({.*?})\\s*-->"
        guard let startRegex = try? NSRegularExpression(pattern: startPattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        let matches = startRegex.matches(in: markdown, options: [], range: range)
        let mutable = NSMutableString(string: markdown)
        var removed = false

        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }
            let jsonRange = match.range(at: 1)
            let json = (markdown as NSString).substring(with: jsonRange)
            guard let existing = CommentCodec.decode(json: json), existing.id == id else {
                continue
            }
            mutable.replaceCharacters(in: match.range, with: "")
            removed = true
            break
        }

        guard removed else { return nil }
        let endPattern = "<!--\\s*MV-COMMENT-END\\s+\(NSRegularExpression.escapedPattern(for: id))\\s*-->"
        guard let endRegex = try? NSRegularExpression(pattern: endPattern, options: []) else {
            return mutable as String
        }
        let current = mutable as String
        let endRange = NSRange(current.startIndex..<current.endIndex, in: current)
        let result = endRegex.stringByReplacingMatches(in: current, options: [], range: endRange, withTemplate: "")
        return result
    }

    private func indexForUTF8Offset(_ offset: Int, in string: String) -> String.Index? {
        guard offset >= 0 else { return nil }
        let utf8 = string.utf8
        guard offset <= utf8.count else { return nil }
        let utf8Index = utf8.index(utf8.startIndex, offsetBy: offset)
        return utf8Index.samePosition(in: string)
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
}
