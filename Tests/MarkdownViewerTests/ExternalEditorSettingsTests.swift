import XCTest
@testable import MarkdownViewer

final class ExternalEditorSettingsTests: XCTestCase {

    // MARK: - UserDefaults backup/restore for test isolation

    private let editorAppURLKey = "externalEditorAppURL"
    private let editorDisplayNameKey = "externalEditorDisplayName"
    private let shortcutKeyKey = "externalEditorShortcutKey"
    private let shortcutModifiersKey = "externalEditorShortcutModifiers"

    private var savedEditorAppURL: Any?
    private var savedEditorDisplayName: Any?
    private var savedShortcutKey: Any?
    private var savedShortcutModifiers: Any?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        savedEditorAppURL = defaults.object(forKey: editorAppURLKey)
        savedEditorDisplayName = defaults.object(forKey: editorDisplayNameKey)
        savedShortcutKey = defaults.object(forKey: shortcutKeyKey)
        savedShortcutModifiers = defaults.object(forKey: shortcutModifiersKey)

        // Clear state so each test starts fresh
        defaults.removeObject(forKey: editorAppURLKey)
        defaults.removeObject(forKey: editorDisplayNameKey)
        defaults.removeObject(forKey: shortcutKeyKey)
        defaults.removeObject(forKey: shortcutModifiersKey)

        let settings = ExternalEditorSettings.shared
        settings.clearEditor()
        settings.clearShortcut()
        // Restore default shortcut key to "e" with Cmd, matching the class defaults
        settings.setShortcut(key: "e", modifiers: .command)
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        restoreDefault(defaults, key: editorAppURLKey, value: savedEditorAppURL)
        restoreDefault(defaults, key: editorDisplayNameKey, value: savedEditorDisplayName)
        restoreDefault(defaults, key: shortcutKeyKey, value: savedShortcutKey)
        restoreDefault(defaults, key: shortcutModifiersKey, value: savedShortcutModifiers)
        super.tearDown()
    }

    private func restoreDefault(_ defaults: UserDefaults, key: String, value: Any?) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - displayName(for:) tests

    func testDisplayNameForStandardApp() {
        let url = URL(fileURLWithPath: "/Applications/Sublime Text.app")
        XCTAssertEqual(ExternalEditorSettings.displayName(for: url), "Sublime Text")
    }

    func testDisplayNameForSingleWordApp() {
        let url = URL(fileURLWithPath: "/Applications/TextEdit.app")
        XCTAssertEqual(ExternalEditorSettings.displayName(for: url), "TextEdit")
    }

    func testDisplayNameForNestedApp() {
        let url = URL(fileURLWithPath: "/Applications/Utilities/Terminal.app")
        XCTAssertEqual(ExternalEditorSettings.displayName(for: url), "Terminal")
    }

    func testDisplayNameForPathWithoutExtension() {
        let url = URL(fileURLWithPath: "/usr/local/bin/vim")
        XCTAssertEqual(ExternalEditorSettings.displayName(for: url), "vim")
    }

    func testDisplayNameForRootURL() {
        // URL(fileURLWithPath: "/") has an empty lastPathComponent after removing extension
        let url = URL(fileURLWithPath: "/")
        let name = ExternalEditorSettings.displayName(for: url)
        // The lastPathComponent of "/" is "/", deleting path extension still gives "/"
        // so name should not be empty
        XCTAssertFalse(name.isEmpty)
    }

    // MARK: - shortcutDisplayString tests

    func testShortcutDisplayStringCommandOnly() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "e", modifiers: .command)
        XCTAssertEqual(settings.shortcutDisplayString, "\u{2318}E")
    }

    func testShortcutDisplayStringCommandShift() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "o", modifiers: [.command, .shift])
        XCTAssertEqual(settings.shortcutDisplayString, "\u{21E7}\u{2318}O")
    }

    func testShortcutDisplayStringAllModifiers() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "x", modifiers: [.control, .option, .shift, .command])
        XCTAssertEqual(settings.shortcutDisplayString, "\u{2303}\u{2325}\u{21E7}\u{2318}X")
    }

    func testShortcutDisplayStringNoModifiers() {
        let settings = ExternalEditorSettings.shared
        settings.shortcutKey = "f"
        settings.shortcutModifiers = 0
        XCTAssertEqual(settings.shortcutDisplayString, "F")
    }

    func testShortcutDisplayStringOptionCommand() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "t", modifiers: [.option, .command])
        XCTAssertEqual(settings.shortcutDisplayString, "\u{2325}\u{2318}T")
    }

    func testShortcutDisplayStringControlOnly() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "c", modifiers: .control)
        XCTAssertEqual(settings.shortcutDisplayString, "\u{2303}C")
    }

    // MARK: - menuItemTitle tests

    func testMenuItemTitleWithNoEditor() {
        let settings = ExternalEditorSettings.shared
        settings.clearEditor()
        XCTAssertEqual(settings.menuItemTitle, "Open in External Editor")
    }

    func testMenuItemTitleWithEditorConfigured() {
        let settings = ExternalEditorSettings.shared
        settings.setEditor(url: URL(fileURLWithPath: "/Applications/Sublime Text.app"))
        XCTAssertEqual(settings.menuItemTitle, "Open in Sublime Text")
    }

    func testMenuItemTitleUpdatesAfterEditorChange() {
        let settings = ExternalEditorSettings.shared
        settings.setEditor(url: URL(fileURLWithPath: "/Applications/TextEdit.app"))
        XCTAssertEqual(settings.menuItemTitle, "Open in TextEdit")

        settings.setEditor(url: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"))
        XCTAssertEqual(settings.menuItemTitle, "Open in Visual Studio Code")
    }

    func testMenuItemTitleAfterClearEditor() {
        let settings = ExternalEditorSettings.shared
        settings.setEditor(url: URL(fileURLWithPath: "/Applications/Sublime Text.app"))
        settings.clearEditor()
        XCTAssertEqual(settings.menuItemTitle, "Open in External Editor")
    }

    // MARK: - keyboardShortcut tests

    func testKeyboardShortcutIsNotNilWithValidKey() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "e", modifiers: .command)
        XCTAssertNotNil(settings.keyboardShortcut)
    }

    func testKeyboardShortcutIsNilWhenKeyEmpty() {
        let settings = ExternalEditorSettings.shared
        settings.clearShortcut()
        XCTAssertNil(settings.keyboardShortcut)
    }

    // MARK: - setShortcut / clearShortcut tests

    func testSetShortcutUpdatesKeyAndModifiers() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "T", modifiers: [.command, .shift])
        XCTAssertEqual(settings.shortcutKey, "t")  // lowercased
        XCTAssertEqual(settings.shortcutModifiers, NSEvent.ModifierFlags([.command, .shift]).rawValue)
    }

    func testSetShortcutLowercasesKey() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "Z", modifiers: .command)
        XCTAssertEqual(settings.shortcutKey, "z")
    }

    func testClearShortcutResetsKeyAndModifiers() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "e", modifiers: .command)
        settings.clearShortcut()
        XCTAssertEqual(settings.shortcutKey, "")
        XCTAssertEqual(settings.shortcutModifiers, 0)
    }

    // MARK: - setEditor / clearEditor tests

    func testSetEditorUpdatesURLAndDisplayName() {
        let settings = ExternalEditorSettings.shared
        let url = URL(fileURLWithPath: "/Applications/Sublime Text.app")
        settings.setEditor(url: url)
        XCTAssertEqual(settings.editorAppURL, url)
        XCTAssertEqual(settings.editorDisplayName, "Sublime Text")
    }

    func testClearEditorResetsURLAndDisplayName() {
        let settings = ExternalEditorSettings.shared
        settings.setEditor(url: URL(fileURLWithPath: "/Applications/TextEdit.app"))
        settings.clearEditor()
        XCTAssertNil(settings.editorAppURL)
        XCTAssertEqual(settings.editorDisplayName, "External Editor")
    }

    func testSetEditorMultipleTimes() {
        let settings = ExternalEditorSettings.shared
        settings.setEditor(url: URL(fileURLWithPath: "/Applications/TextEdit.app"))
        XCTAssertEqual(settings.editorDisplayName, "TextEdit")

        settings.setEditor(url: URL(fileURLWithPath: "/Applications/Nova.app"))
        XCTAssertEqual(settings.editorDisplayName, "Nova")
        XCTAssertEqual(settings.editorAppURL, URL(fileURLWithPath: "/Applications/Nova.app"))
    }

    // MARK: - shortcutIdentity tests

    func testShortcutIdentityFormat() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "e", modifiers: .command)
        let expected = "e-\(NSEvent.ModifierFlags.command.rawValue)"
        XCTAssertEqual(settings.shortcutIdentity, expected)
    }

    func testShortcutIdentityChangesWhenKeyChanges() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "e", modifiers: .command)
        let identity1 = settings.shortcutIdentity

        settings.setShortcut(key: "o", modifiers: .command)
        let identity2 = settings.shortcutIdentity

        XCTAssertNotEqual(identity1, identity2)
    }

    func testShortcutIdentityChangesWhenModifiersChange() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "e", modifiers: .command)
        let identity1 = settings.shortcutIdentity

        settings.setShortcut(key: "e", modifiers: [.command, .shift])
        let identity2 = settings.shortcutIdentity

        XCTAssertNotEqual(identity1, identity2)
    }

    func testShortcutIdentityStableWhenUnchanged() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "e", modifiers: .command)
        let identity1 = settings.shortcutIdentity
        let identity2 = settings.shortcutIdentity
        XCTAssertEqual(identity1, identity2)
    }

    func testShortcutIdentityAfterClear() {
        let settings = ExternalEditorSettings.shared
        settings.setShortcut(key: "e", modifiers: .command)
        let identityBefore = settings.shortcutIdentity

        settings.clearShortcut()
        let identityAfter = settings.shortcutIdentity

        XCTAssertNotEqual(identityBefore, identityAfter)
        XCTAssertEqual(identityAfter, "-0")
    }
}
