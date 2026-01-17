import Markdown

struct RenderedMarkdown {
    let html: String
    let outline: [OutlineItem]
}

struct SourceMapper {
    private let lineStartOffsets: [Int]

    init(source: String) {
        var offsets: [Int] = [0]
        var index = 0
        for byte in source.utf8 {
            if byte == 10 {
                offsets.append(index + 1)
            }
            index += 1
        }
        lineStartOffsets = offsets
    }

    func offset(for location: SourceLocation) -> Int? {
        guard location.line > 0, location.line <= lineStartOffsets.count else { return nil }
        let lineStart = lineStartOffsets[location.line - 1]
        let columnOffset = max(0, location.column - 1)
        return lineStart + columnOffset
    }
}

struct HeadingSlugger {
    private var counts: [String: Int] = [:]

    mutating func slug(for title: String) -> String {
        let base = slugify(title)
        let key = base.isEmpty ? "section" : base
        let count = counts[key, default: 0]
        counts[key] = count + 1
        if count == 0 {
            return key
        }
        return "\(key)-\(count)"
    }

    private func slugify(_ title: String) -> String {
        let lowercased = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = ""
        var needsHyphen = false

        for scalar in lowercased.unicodeScalars {
            guard scalar.isASCII else {
                needsHyphen = true
                continue
            }
            let value = scalar.value
            let isLetter = value >= 97 && value <= 122
            let isDigit = value >= 48 && value <= 57
            if isLetter || isDigit {
                if needsHyphen && !result.isEmpty {
                    result.append("-")
                }
                needsHyphen = false
                result.append(Character(scalar))
            } else {
                needsHyphen = true
            }
        }

        return result
    }
}

struct MarkdownRenderer: MarkupWalker {
    var result = ""
    var outline: [OutlineItem] = []
    var slugger = HeadingSlugger()
    private let sourceMapper: SourceMapper?
    private let sourceOffsetBase: Int

    init(source: String, sourceOffsetBase: Int) {
        sourceMapper = SourceMapper(source: source)
        self.sourceOffsetBase = sourceOffsetBase
    }

    init() {
        sourceMapper = nil
        sourceOffsetBase = 0
    }

    mutating func render(_ document: Document) -> RenderedMarkdown {
        result = ""
        outline = []
        slugger = HeadingSlugger()
        for child in document.children {
            visit(child)
        }
        return RenderedMarkdown(html: result, outline: outline)
    }

    mutating func visit(_ markup: any Markup) {
        switch markup {
        case let heading as Heading:
            let title = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            let anchorID = slugger.slug(for: title)
            if !title.isEmpty {
                outline.append(OutlineItem(title: title, level: heading.level, anchorID: anchorID))
            }
            result += "<h\(heading.level) id=\"\(anchorID)\">"
            for child in heading.children { visit(child) }
            result += "</h\(heading.level)>\n"
        case let paragraph as Paragraph:
            result += "<p>"
            for child in paragraph.children { visit(child) }
            result += "</p>\n"
        case let text as Markdown.Text:
            appendText(text)
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
        case let htmlBlock as HTMLBlock:
            if shouldRenderHTML(htmlBlock.rawHTML) {
                result += htmlBlock.rawHTML
            }
        case let inlineHTML as InlineHTML:
            if shouldRenderHTML(inlineHTML.rawHTML) {
                result += inlineHTML.rawHTML
            }
        default:
            for child in markup.children {
                visit(child)
            }
        }
    }

    private mutating func appendText(_ text: Markdown.Text) {
        let escaped = escapeHTML(text.string)
        guard let range = text.range,
              let mapper = sourceMapper,
              let start = mapper.offset(for: range.lowerBound),
              let end = mapper.offset(for: range.upperBound) else {
            result += escaped
            return
        }
        let startOffset = start + sourceOffsetBase
        let endOffset = end + sourceOffsetBase
        result += "<span data-mv-text-start=\"\(startOffset)\" data-mv-text-end=\"\(endOffset)\">"
        result += escaped
        result += "</span>"
    }

    private func shouldRenderHTML(_ html: String) -> Bool {
        html.contains("MV-COMMENT-") || html.contains(CommentConstants.headerPrefix)
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
