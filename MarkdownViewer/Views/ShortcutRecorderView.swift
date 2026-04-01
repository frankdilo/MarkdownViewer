import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    @ObservedObject var settings: ExternalEditorSettings
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private static let reservedKeys: Set<String> = [
        "q", "w", "c", "v", "x", "z", "a", "o", "t", "n", "f", "s", "p", "h", "m", ",",
        "r", "g", "+", "-", "0", "[", "]",
        "1", "2", "3", "4", "5", "6", "7", "8", "9"
    ]

    private static let reservedCmdShiftKeys: Set<String> = ["[", "]", "g"]

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
                // Require at least one modifier key (Cmd, Ctrl, or Option)
                let requiredMods: NSEvent.ModifierFlags = [.command, .control, .option]
                guard !flags.intersection(requiredMods).isEmpty else {
                    NSSound.beep()
                    return nil
                }
                // Reject reserved Cmd-only shortcuts
                if flags == [.command] && Self.reservedKeys.contains(chars.lowercased()) {
                    NSSound.beep()
                    return nil
                }
                // Reject reserved Cmd+Shift shortcuts used by the app
                if flags == [.command, .shift] && Self.reservedCmdShiftKeys.contains(chars.lowercased()) {
                    NSSound.beep()
                    return nil
                }
                settings.setShortcut(key: chars, modifiers: flags)
                stopRecording()
                return nil
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
