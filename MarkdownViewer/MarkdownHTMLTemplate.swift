import Foundation

struct MarkdownHTMLTemplate {
    static let shared = MarkdownHTMLTemplate()

    private static let titleToken = "__MARKDOWN_VIEWER_TITLE__"
    private static let bodyToken = "__MARKDOWN_VIEWER_BODY__"

    private let template: String

    private init() {
        if let url = Bundle.module.url(forResource: "markdown", withExtension: "html"),
           let data = try? Data(contentsOf: url),
           let string = String(data: data, encoding: .utf8) {
            template = string
        } else {
            template = Self.fallbackTemplate
        }
    }

    func render(body: String, title: String) -> String {
        template
            .replacingOccurrences(of: Self.titleToken, with: title)
            .replacingOccurrences(of: Self.bodyToken, with: body)
    }

    private static let fallbackTemplate = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset=\"UTF-8\">
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
        <title>\(titleToken)</title>
    </head>
    <body>
        \(bodyToken)
    </body>
    </html>
    """
}
