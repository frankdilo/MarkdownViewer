import Foundation
import SwiftUI

final class ExternalEditorSettings: ObservableObject {
    static let shared = ExternalEditorSettings()

    @Published var editorAppURL: URL? {
        didSet { save() }
    }
    @Published var editorDisplayName: String = "External Editor" {
        didSet { save() }
    }
    @Published var shortcutKey: String = "e" {
        didSet { save() }
    }
    @Published var shortcutModifiers: UInt = NSEvent.ModifierFlags.command.rawValue {
        didSet { save() }
    }

    var menuItemTitle: String {
        if editorAppURL != nil {
            return "Open in \(editorDisplayName)"
        }
        return "Open in External Editor"
    }

    var keyboardShortcut: KeyboardShortcut? {
        guard let char = shortcutKey.lowercased().first else { return nil }
        let flags = NSEvent.ModifierFlags(rawValue: shortcutModifiers)
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return KeyboardShortcut(KeyEquivalent(char), modifiers: modifiers)
    }

    var shortcutIdentity: String {
        "\(shortcutKey)-\(shortcutModifiers)"
    }

    var shortcutDisplayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: shortcutModifiers)
        var parts: [String] = []
        if flags.contains(.control) { parts.append("\u{2303}") }
        if flags.contains(.option) { parts.append("\u{2325}") }
        if flags.contains(.shift) { parts.append("\u{21E7}") }
        if flags.contains(.command) { parts.append("\u{2318}") }
        parts.append(shortcutKey.uppercased())
        return parts.joined()
    }

    var editorIcon: NSImage? {
        guard let url = editorAppURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private var isLoading = false
    private let defaults = UserDefaults.standard
    private let editorAppURLKey = "externalEditorAppURL"
    private let editorDisplayNameKey = "externalEditorDisplayName"
    private let shortcutKeyKey = "externalEditorShortcutKey"
    private let shortcutModifiersKey = "externalEditorShortcutModifiers"

    private init() {
        load()
    }

    func setEditor(url: URL) {
        editorAppURL = url
        editorDisplayName = Self.displayName(for: url)
    }

    func clearEditor() {
        editorAppURL = nil
        editorDisplayName = "External Editor"
    }

    func setShortcut(key: String, modifiers: NSEvent.ModifierFlags) {
        shortcutKey = key.lowercased()
        shortcutModifiers = modifiers.rawValue
    }

    func clearShortcut() {
        shortcutKey = ""
        shortcutModifiers = 0
    }

    static func presentEditorChooserPanel(message: String = "Choose an editor application") -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = message
        panel.prompt = "Choose"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func displayName(for appURL: URL) -> String {
        let name = appURL.deletingPathExtension().lastPathComponent
        return name.isEmpty ? "External Editor" : name
    }

    private func save() {
        guard !isLoading else { return }
        if let url = editorAppURL {
            defaults.set(url.path, forKey: editorAppURLKey)
        } else {
            defaults.removeObject(forKey: editorAppURLKey)
        }
        defaults.set(editorDisplayName, forKey: editorDisplayNameKey)
        defaults.set(shortcutKey, forKey: shortcutKeyKey)
        defaults.set(shortcutModifiers, forKey: shortcutModifiersKey)
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        if let path = defaults.string(forKey: editorAppURLKey) {
            editorAppURL = URL(fileURLWithPath: path)
        }
        if let name = defaults.string(forKey: editorDisplayNameKey) {
            editorDisplayName = name
        }
        if let key = defaults.string(forKey: shortcutKeyKey), !key.isEmpty {
            shortcutKey = key
        }
        if defaults.object(forKey: shortcutModifiersKey) != nil {
            shortcutModifiers = UInt(defaults.integer(forKey: shortcutModifiersKey))
        }
    }
}
