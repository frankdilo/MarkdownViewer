import AppKit
import SwiftUI

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
