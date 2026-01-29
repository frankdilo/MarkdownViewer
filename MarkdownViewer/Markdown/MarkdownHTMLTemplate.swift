import Foundation

struct MarkdownHTMLTemplate {
    static let shared = MarkdownHTMLTemplate()

    private static let titleToken = "__MARKDOWN_VIEWER_TITLE__"
    private static let bodyToken = "__MARKDOWN_VIEWER_BODY__"
    private static let styleToken = "__MARKDOWN_VIEWER_STYLE_BLOCKS__"
    private static let scriptToken = "__MARKDOWN_VIEWER_SCRIPT_BLOCKS__"

    private let template: String
    private let styleBlocks: String
    private let scriptBlocks: String

    private init() {
        if let url = Bundle.module.url(forResource: "markdown", withExtension: "html"),
           let data = try? Data(contentsOf: url),
           let string = String(data: data, encoding: .utf8) {
            template = string
        } else {
            template = Self.fallbackTemplate
        }
        styleBlocks = Self.buildStyleBlocks()
        scriptBlocks = Self.buildScriptBlocks()
    }

    func render(body: String, title: String) -> String {
        template
            .replacingOccurrences(of: Self.titleToken, with: title)
            .replacingOccurrences(of: Self.bodyToken, with: body)
            .replacingOccurrences(of: Self.styleToken, with: styleBlocks)
            .replacingOccurrences(of: Self.scriptToken, with: scriptBlocks)
    }

    private static func buildStyleBlocks() -> String {
        let lightHighlight = resourceString(name: "github.min", extension: "css")
        let darkHighlight = resourceString(name: "github-dark.min", extension: "css")
        let markdown = resourceString(name: "markdown", extension: "css")
        return """
        <style media="(prefers-color-scheme: light)">
        \(lightHighlight)
        </style>
        <style media="(prefers-color-scheme: dark)">
        \(darkHighlight)
        </style>
        <style>
        \(markdown)
        </style>
        """
    }

    private static func buildScriptBlocks() -> String {
        let highlight = safeScript(resourceString(name: "highlight.min", extension: "js"))
        let find = safeScript(resourceString(name: "find", extension: "js"))
        let dagre = safeScript(resourceString(name: "dagre.min", extension: "js"))
        let beautifulMermaid = safeScript(resourceString(name: "beautiful-mermaid", extension: "js"))
        let mermaidInit = safeScript(resourceString(name: "beautiful-mermaid-init", extension: "js"))
        let toc = safeScript(resourceString(name: "toc", extension: "js"))
        return """
        <script>
        \(highlight)
        </script>
        <script>
        \(find)
        </script>
        <script>
        \(dagre)
        </script>
        <script>
        \(beautifulMermaid)
        </script>
        <script>
        \(mermaidInit)
        </script>
        <script>
        \(toc)
        </script>
        """
    }

    private static func resourceString(name: String, extension ext: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private static func safeScript(_ script: String) -> String {
        script.replacingOccurrences(of: "</script>", with: "<\\/script>")
    }

    private static let fallbackTemplate = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset=\"UTF-8\">
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
        <title>\(titleToken)</title>
        \(styleToken)
    </head>
    <body>
        \(bodyToken)
        \(scriptToken)
    </body>
    </html>
    """
}
