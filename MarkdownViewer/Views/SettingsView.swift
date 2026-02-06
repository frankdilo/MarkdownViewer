import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = ExternalEditorSettings.shared

    var body: some View {
        Form {
            Section {
                editorSection
            } header: {
                Text("External Editor")
            }

            Section {
                shortcutSection
            } header: {
                Text("Keyboard Shortcut")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }

    @ViewBuilder
    private var editorSection: some View {
        HStack(spacing: 12) {
            if let icon = settings.editorIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                if settings.editorAppURL != nil {
                    Text(settings.editorDisplayName)
                        .fontWeight(.medium)
                    Text(settings.editorAppURL?.path ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No editor selected")
                        .foregroundColor(.secondary)
                    Text("You will be prompted to choose on first use")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }

        HStack {
            Button("Choose\u{2026}") {
                chooseEditor()
            }
            if settings.editorAppURL != nil {
                Button("Clear") {
                    settings.clearEditor()
                }
            }
        }
    }

    @ViewBuilder
    private var shortcutSection: some View {
        HStack {
            Text("Shortcut:")
            ShortcutRecorderView(settings: settings)
        }
    }

    private func chooseEditor() {
        if let url = ExternalEditorSettings.presentEditorChooserPanel(message: "Select an editor application") {
            settings.setEditor(url: url)
        }
    }
}

struct ShortcutRecorderView: View {
    @ObservedObject var settings: ExternalEditorSettings
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private static let reservedKeys: Set<String> = [
        "q", "w", "c", "v", "x", "z", "a", "o", "t", "n", "f", "s", "p", "h", "m", ","
    ]

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording
                          ? Color.accentColor.opacity(0.1)
                          : Color(nsColor: .controlBackgroundColor))
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isRecording
                                  ? Color.accentColor
                                  : Color(nsColor: .separatorColor),
                                  lineWidth: 1)

                if isRecording {
                    Text("Type shortcut\u{2026}")
                        .foregroundColor(.accentColor)
                } else if !settings.shortcutKey.isEmpty {
                    Text(settings.shortcutDisplayString)
                        .font(.system(.body, design: .rounded))
                } else {
                    Text("Click to record")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, height: 24)
            .onTapGesture {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }

            if !settings.shortcutKey.isEmpty {
                Button {
                    settings.clearShortcut()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove keyboard shortcut")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if let chars = event.charactersIgnoringModifiers,
               chars.count == 1,
               let char = chars.first,
               char.asciiValue.map({ $0 >= 32 && $0 < 127 }) == true {
                // Reject reserved Cmd-only shortcuts
                if flags == [.command] && Self.reservedKeys.contains(chars.lowercased()) {
                    NSSound.beep()
                    return nil
                }
                settings.setShortcut(key: chars, modifiers: flags)
                stopRecording()
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
