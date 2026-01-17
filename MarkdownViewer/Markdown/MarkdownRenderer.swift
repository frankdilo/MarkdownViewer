import Foundation
import Markdown

struct OutlineItem: Identifiable {
    let id = UUID()
    let title: String
    let level: Int
    let anchorID: String
}

struct RenderedMarkdown {
    let html: String
    let outline: [OutlineItem]
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
        case let inlineHTML as InlineHTML:
            result += escapeHTML(inlineHTML.rawHTML)
        case let htmlBlock as HTMLBlock:
            result += escapeHTML(htmlBlock.rawHTML)
            result += "\n"
        default:
            for child in markup.children {
                visit(child)
            }
        }
    }

    private func escapeHTML(_ string: String) -> String {
        var result = ""
        var index = string.startIndex

        while index < string.endIndex {
            let character = string[index]
            switch character {
            case "&":
                if let semiIndex = string[index...].firstIndex(of: ";") {
                    let entity = string[index...semiIndex]
                    if isHTMLEntity(entity) {
                        result.append(contentsOf: entity)
                        index = string.index(after: semiIndex)
                        continue
                    }
                }
                result.append("&amp;")
            case "<":
                result.append("&lt;")
            case ">":
                result.append("&gt;")
            case "\"":
                result.append("&quot;")
            default:
                result.append(character)
            }
            index = string.index(after: index)
        }

        return result
    }

    private func isHTMLEntity(_ entity: Substring) -> Bool {
        guard entity.first == "&", entity.last == ";" else { return false }
        let name = entity.dropFirst().dropLast()
        guard !name.isEmpty else { return false }

        if name.first == "#" {
            let number = name.dropFirst()
            guard !number.isEmpty else { return false }
            if number.first == "x" || number.first == "X" {
                return number.dropFirst().unicodeScalars.allSatisfy { scalar in
                    let value = scalar.value
                    return (value >= 48 && value <= 57)
                        || (value >= 65 && value <= 70)
                        || (value >= 97 && value <= 102)
                }
            }
            return number.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        }

        return name.unicodeScalars.allSatisfy {
            CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
        }
    }
}
