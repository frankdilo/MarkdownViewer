import XCTest
@testable import MarkdownViewer

final class DocumentStateTests: XCTestCase {

    // MARK: - loadFile

    func testLoadFileSetsHTMLContentAndTitle() throws {
        let file = try TemporaryFile.create(named: "test.md")
        defer { file.cleanup() }
        try "# Hello\nWorld".write(to: file.url, atomically: true, encoding: .utf8)

        let state = DocumentState()
        state.loadFile(at: file.url)

        XCTAssertTrue(state.htmlContent.contains("Hello"))
        XCTAssertTrue(state.htmlContent.contains("World"))
        XCTAssertEqual(state.title, "test.md")
        XCTAssertEqual(state.currentURL, file.url)
    }

    func testLoadFileResetsFileChangedFlag() throws {
        let file = try TemporaryFile.create(named: "note.md")
        defer { file.cleanup() }
        try "# Note".write(to: file.url, atomically: true, encoding: .utf8)

        let state = DocumentState()
        state.fileChanged = true
        state.loadFile(at: file.url)

        XCTAssertFalse(state.fileChanged)
    }

    func testLoadFileParsesOutlineItems() throws {
        let file = try TemporaryFile.create(named: "outline.md")
        defer { file.cleanup() }
        try "# Title\n## Section One\n## Section Two".write(to: file.url, atomically: true, encoding: .utf8)

        let state = DocumentState()
        state.loadFile(at: file.url)

        // normalizedOutline drops the single H1 and shifts levels
        XCTAssertEqual(state.outlineItems.count, 2)
        XCTAssertEqual(state.outlineItems[0].title, "Section One")
        XCTAssertEqual(state.outlineItems[1].title, "Section Two")
    }

    func testLoadFileWithFrontMatterIncludesMetadataInHTML() throws {
        let file = try TemporaryFile.create(named: "meta.md")
        defer { file.cleanup() }
        try "---\ntitle: My Doc\nauthor: Test\n---\n# Content".write(to: file.url, atomically: true, encoding: .utf8)

        let state = DocumentState()
        state.loadFile(at: file.url)

        XCTAssertTrue(state.htmlContent.contains("My Doc"))
        XCTAssertTrue(state.htmlContent.contains("Author"))
        XCTAssertTrue(state.htmlContent.contains("front-matter"))
    }

    func testLoadFileWithInvalidPathSetsErrorContent() {
        let badURL = URL(fileURLWithPath: "/nonexistent/path/file.md")
        let state = DocumentState()
        state.loadFile(at: badURL)

        XCTAssertTrue(state.htmlContent.contains("Error loading file"))
        XCTAssertEqual(state.title, "Error")
        XCTAssertTrue(state.outlineItems.isEmpty)
    }

    func testLoadFileEscapesHTMLInFrontMatter() throws {
        let file = try TemporaryFile.create(named: "escape.md")
        defer { file.cleanup() }
        try "---\ntitle: <script>alert('xss')</script>\n---\n# Safe".write(to: file.url, atomically: true, encoding: .utf8)

        let state = DocumentState()
        state.loadFile(at: file.url)

        XCTAssertTrue(state.htmlContent.contains("&lt;script&gt;"))
        XCTAssertFalse(state.htmlContent.contains("<script>alert"))
    }

    // MARK: - reload

    func testReloadSetsNewReloadToken() throws {
        let file = try TemporaryFile.create(named: "reload.md")
        defer { file.cleanup() }
        try "# Reload Me".write(to: file.url, atomically: true, encoding: .utf8)

        let state = DocumentState()
        state.loadFile(at: file.url)
        let tokenBefore = state.reloadToken

        state.reload()

        XCTAssertNotNil(state.reloadToken)
        XCTAssertNotEqual(state.reloadToken, tokenBefore)
    }

    func testReloadWithoutCurrentURLIsNoOp() {
        let state = DocumentState()
        let tokenBefore = state.reloadToken

        state.reload()

        XCTAssertEqual(state.reloadToken, tokenBefore)
    }

    func testReloadReflectsUpdatedFileContent() throws {
        let file = try TemporaryFile.create(named: "changing.md")
        defer { file.cleanup() }
        try "# Version 1".write(to: file.url, atomically: true, encoding: .utf8)

        let state = DocumentState()
        state.loadFile(at: file.url)
        XCTAssertTrue(state.htmlContent.contains("Version 1"))

        try "# Version 2".write(to: file.url, atomically: true, encoding: .utf8)
        state.reload()

        XCTAssertTrue(state.htmlContent.contains("Version 2"))
        XCTAssertFalse(state.htmlContent.contains("Version 1"))
    }

    // MARK: - Zoom

    func testZoomInIncreasesLevel() {
        let state = DocumentState()
        XCTAssertEqual(state.zoomLevel, 1.0)

        state.zoomIn()

        XCTAssertEqual(state.zoomLevel, 1.1, accuracy: 0.001)
    }

    func testZoomOutDecreasesLevel() {
        let state = DocumentState()

        state.zoomOut()

        XCTAssertEqual(state.zoomLevel, 0.9, accuracy: 0.001)
    }

    func testZoomInClampsAtMaximum() {
        let state = DocumentState()
        state.zoomLevel = 2.95

        state.zoomIn()

        XCTAssertEqual(state.zoomLevel, 3.0, accuracy: 0.001)

        state.zoomIn()

        XCTAssertEqual(state.zoomLevel, 3.0, accuracy: 0.001)
    }

    func testZoomOutClampsAtMinimum() {
        let state = DocumentState()
        state.zoomLevel = 0.55

        state.zoomOut()

        XCTAssertEqual(state.zoomLevel, 0.5, accuracy: 0.001)

        state.zoomOut()

        XCTAssertEqual(state.zoomLevel, 0.5, accuracy: 0.001)
    }

    func testResetZoomRestoresToDefault() {
        let state = DocumentState()
        state.zoomIn()
        state.zoomIn()

        state.resetZoom()

        XCTAssertEqual(state.zoomLevel, 1.0)
    }

    // MARK: - Find Bar

    func testShowFindBarSetsIsShowing() {
        let state = DocumentState()
        XCTAssertFalse(state.isShowingFindBar)

        state.showFindBar()

        XCTAssertTrue(state.isShowingFindBar)
    }

    func testShowFindBarUpdatesFocusToken() {
        let state = DocumentState()
        let tokenBefore = state.findFocusToken

        state.showFindBar()

        XCTAssertNotEqual(state.findFocusToken, tokenBefore)
    }

    func testHideFindBarClearsShowingAndSendsClearRequest() {
        let state = DocumentState()
        state.showFindBar()
        state.findQuery = "search"
        state.findNext()  // sets findRequest to non-empty query
        let requestBeforeHide = state.findRequest
        XCTAssertEqual(requestBeforeHide?.query, "search")

        state.hideFindBar()

        XCTAssertFalse(state.isShowingFindBar)
        XCTAssertNotNil(state.findRequest)
        XCTAssertEqual(state.findRequest?.query, "")
        // The token should differ from before, proving hideFindBar issued a new request
        XCTAssertNotEqual(state.findRequest?.token, requestBeforeHide?.token)
    }

    func testUpdateFindResultsTrimsWhitespaceAndSetsRequest() {
        let state = DocumentState()
        state.findQuery = "  hello  "

        state.updateFindResults()

        XCTAssertEqual(state.findRequest?.query, "hello")
        XCTAssertEqual(state.findRequest?.direction, .forward)
        XCTAssertTrue(state.findRequest?.reset ?? false)
    }

    func testUpdateFindResultsWithEmptyQuerySendsClearRequest() {
        let state = DocumentState()
        state.findQuery = "   "

        state.updateFindResults()

        XCTAssertEqual(state.findRequest?.query, "")
        XCTAssertEqual(state.findRequest?.direction, .forward)
        XCTAssertTrue(state.findRequest?.reset ?? false)
    }

    func testFindNextSetsForwardDirection() {
        let state = DocumentState()
        state.findQuery = "term"

        state.findNext()

        XCTAssertEqual(state.findRequest?.query, "term")
        XCTAssertEqual(state.findRequest?.direction, .forward)
        XCTAssertFalse(state.findRequest?.reset ?? true)
    }

    func testFindPreviousSetsBackwardDirection() {
        let state = DocumentState()
        state.findQuery = "term"

        state.findPrevious()

        XCTAssertEqual(state.findRequest?.query, "term")
        XCTAssertEqual(state.findRequest?.direction, .backward)
        XCTAssertFalse(state.findRequest?.reset ?? true)
    }

    func testFindNextWithEmptyQuerySendsClearRequest() {
        let state = DocumentState()
        state.findQuery = ""

        state.findNext()

        XCTAssertEqual(state.findRequest?.query, "")
    }
}
