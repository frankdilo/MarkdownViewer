import XCTest
@testable import MarkdownViewer

/// Tests for the Escape key dismissal priority logic from ContentView.
///
/// ContentView's .onExitCommand handler uses a priority chain:
/// 1. If fileChanged is true, dismiss the notification (set fileChanged = false)
/// 2. Otherwise, if the find bar is showing, hide it
///
/// Since ContentView depends on SwiftUI framework bindings and cannot be
/// render-tested in a unit test environment, we use behavioral extraction
/// to test the decision logic directly.
final class EscapeDismissalTests: XCTestCase {

    /// Mirrors the .onExitCommand handler in ContentView.swift (line 82-88).
    /// Returns a description of the action taken for assertion purposes.
    private enum EscapeAction: Equatable {
        case dismissedNotification
        case closedFindBar
        case noAction
    }

    /// Mirrors ContentView.onExitCommand logic.
    /// Mutates state the same way the real handler does.
    private func simulateEscapeKey(on state: DocumentState) -> EscapeAction {
        if state.fileChanged {
            state.fileChanged = false
            return .dismissedNotification
        } else if state.isShowingFindBar {
            state.hideFindBar()
            return .closedFindBar
        }
        return .noAction
    }

    func testEscapeDismissesNotificationBeforeFindBar() {
        let state = DocumentState()
        state.fileChanged = true
        state.showFindBar()

        let action = simulateEscapeKey(on: state)

        XCTAssertEqual(action, .dismissedNotification)
        XCTAssertFalse(state.fileChanged)
        // Find bar should still be open because notification took priority
        XCTAssertTrue(state.isShowingFindBar)
    }

    func testEscapeClosesFindBarWhenNoNotification() {
        let state = DocumentState()
        state.fileChanged = false
        state.showFindBar()

        let action = simulateEscapeKey(on: state)

        XCTAssertEqual(action, .closedFindBar)
        XCTAssertFalse(state.isShowingFindBar)
    }

    func testEscapeDoesNothingWhenNothingActive() {
        let state = DocumentState()
        state.fileChanged = false

        let action = simulateEscapeKey(on: state)

        XCTAssertEqual(action, .noAction)
    }

    func testConsecutiveEscapesDismissNotificationThenFindBar() {
        let state = DocumentState()
        state.fileChanged = true
        state.showFindBar()

        let firstAction = simulateEscapeKey(on: state)
        XCTAssertEqual(firstAction, .dismissedNotification)
        XCTAssertTrue(state.isShowingFindBar)

        let secondAction = simulateEscapeKey(on: state)
        XCTAssertEqual(secondAction, .closedFindBar)
        XCTAssertFalse(state.isShowingFindBar)
    }

    func testEscapeOnlyDismissesNotificationWhenFindBarNotShowing() {
        let state = DocumentState()
        state.fileChanged = true

        let action = simulateEscapeKey(on: state)

        XCTAssertEqual(action, .dismissedNotification)
        XCTAssertFalse(state.fileChanged)
    }
}
