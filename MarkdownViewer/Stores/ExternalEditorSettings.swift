import Foundation
import SwiftUI

final class ExternalEditorSettings: ObservableObject {
    static let shared = ExternalEditorSettings()

    @Published var editorAppURL: URL? {
        didSet { if !isLoading && !isBatching { save() } }
    }
    @Published var editorDisplayName: String = "External Editor" {
        didSet { if !isLoading && !isBatching { save() } }
    }
    @Published var shortcutKey: String = "e" {
        didSet { if !isLoading && !isBatching { save() } }
    }
    @Published var shortcutModifiers: UInt = NSEvent.ModifierFlags.command.rawValue {
        didSet { if !isLoading && !isBatching { save() } }
    }

    var menuItemTitle: String {
        if editorAppURL != nil {
            return "Open in \(editorDisplayName)"
        }
        return "Open in External Editor"
    }

    var keyboardShortcut: KeyboardShortcut? {
        guard let char = shortcutKey.lowercased().first else { return nil }
        var modifiers: EventModifiers = []
        if modifierFlags.contains(.command) { modifiers.insert(.command) }
        if modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if modifierFlags.contains(.option) { modifiers.insert(.option) }
        if modifierFlags.contains(.control) { modifiers.insert(.control) }
        return KeyboardShortcut(KeyEquivalent(char), modifiers: modifiers)
    }

    var shortcutIdentity: String {
        "\(shortcutKey)-\(shortcutModifiers)"
    }

    var shortcutDisplayString: String {
        var parts: [String] = []
        if modifierFlags.contains(.control) { parts.append("\u{2303}") }
        if modifierFlags.contains(.option) { parts.append("\u{2325}") }
        if modifierFlags.contains(.shift) { parts.append("\u{21E7}") }
        if modifierFlags.contains(.command) { parts.append("\u{2318}") }
        parts.append(shortcutKey.uppercased())
        return parts.joined()
    }

    var editorIcon: NSImage? {
        guard let url = editorAppURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// Prevents circular @Published updates during load() from UserDefaults
    private var isLoading = false
    /// Prevents redundant saves during batched multi-property mutations
    private var isBatching = false
    private let defaults = UserDefaults.standard
    private let editorAppURLKey = "externalEditorAppURL"
    private let editorDisplayNameKey = "externalEditorDisplayName"
    private let shortcutKeyKey = "externalEditorShortcutKey"
    private let shortcutModifiersKey = "externalEditorShortcutModifiers"

    /// Decomposes the stored shortcutModifiers UInt into NSEvent.ModifierFlags
    private var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: shortcutModifiers)
    }

    private init() {
        load()
    }

    func setEditor(url: URL) {
        isBatching = true
        editorAppURL = url
        editorDisplayName = Self.displayName(for: url)
        isBatching = false
        save()
    }

    func clearEditor() {
        isBatching = true
        editorAppURL = nil
        editorDisplayName = "External Editor"
        isBatching = false
        save()
    }

    func setShortcut(key: String, modifiers: NSEvent.ModifierFlags) {
        isBatching = true
        shortcutKey = key.lowercased()
        shortcutModifiers = modifiers.rawValue
        isBatching = false
        save()
    }

    func clearShortcut() {
        isBatching = true
        shortcutKey = ""
        shortcutModifiers = 0
        isBatching = false
        save()
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
