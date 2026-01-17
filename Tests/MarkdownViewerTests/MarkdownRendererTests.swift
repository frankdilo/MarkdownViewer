import Markdown
import XCTest
@testable import MarkdownViewer

final class MarkdownRendererTests: XCTestCase {
    func testRenderGeneratesOutlineAndAnchors() {
        let input = """
        # Title
        ## Section
        ## Section
        ### Sub
        """
        let document = Document(parsing: input)
        var renderer = MarkdownRenderer()

        let rendered = renderer.render(document)

        XCTAssertEqual(rendered.outline.map(\.title), ["Title", "Section", "Section", "Sub"])
        XCTAssertEqual(rendered.outline.map(\.anchorID), ["title", "section", "section-1", "sub"])
        XCTAssertEqual(rendered.outline.map(\.level), [1, 2, 2, 3])
        XCTAssertTrue(rendered.html.contains("<h1 id=\"title\">"))
        XCTAssertTrue(rendered.html.contains("<h2 id=\"section-1\">"))
    }

    func testRenderEscapesHTMLCharacters() {
        let input = "This is <tag> & \"quote\""
        let document = Document(parsing: input)
        var renderer = MarkdownRenderer()

        let rendered = renderer.render(document)

        XCTAssertTrue(rendered.html.contains("&lt;tag&gt;"))
        XCTAssertTrue(rendered.html.contains("&amp;"))
        let smartQuotes = "\u{201C}quote\u{201D}"
        XCTAssertTrue(
            rendered.html.contains(smartQuotes)
                || rendered.html.contains("&quot;quote&quot;")
        )
    }

    func testRenderCodeBlocksAndInlineCode() {
        let input = """
        Here is `code`.

        ```swift
        let value = "<tag>"
        ```
        """
        let document = Document(parsing: input)
        var renderer = MarkdownRenderer()

        let rendered = renderer.render(document)

        XCTAssertTrue(rendered.html.contains("<code>code</code>"))
        XCTAssertTrue(rendered.html.contains("language-swift"))
        XCTAssertTrue(rendered.html.contains("&lt;tag&gt;"))
    }

    func testRenderListsQuotesAndLineBreaks() {
        let input = """
        - Item 1
        - Item 2

        > Quote

        Line one  
        Line two
        """
        let document = Document(parsing: input)
        var renderer = MarkdownRenderer()

        let rendered = renderer.render(document)

        XCTAssertTrue(rendered.html.contains("<ul>"))
        XCTAssertTrue(rendered.html.contains("<blockquote>"))
        XCTAssertTrue(rendered.html.contains("<br>"))
    }

    func testRenderLinksImagesTablesAndStrikethrough() {
        let input = """
        [Link](https://example.com)
        ![Alt](image.png)

        | A | B |
        | - | - |
        | 1 | 2 |

        ~~strike~~
        """
        let document = Document(parsing: input)
        var renderer = MarkdownRenderer()

        let rendered = renderer.render(document)

        XCTAssertTrue(rendered.html.contains("<a href=\"https://example.com\">"))
        XCTAssertTrue(rendered.html.contains("<img src=\"image.png\" alt=\"Alt\">"))
        XCTAssertTrue(rendered.html.contains("<table>"))
        XCTAssertTrue(rendered.html.contains("<del>strike</del>"))
    }
}
