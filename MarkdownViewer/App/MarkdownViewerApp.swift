import SwiftUI

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recentFilesStore = RecentFilesStore.shared
    @ObservedObject private var editorSettings = ExternalEditorSettings.shared
    @ObservedObject private var appearanceSettings = AppearanceSettings.shared
    @AppStorage("autoRaiseOnFileChange") private var autoRaiseOnFileChange = false

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    appDelegate.openFileFromPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    ForEach(recentFilesStore.recentFiles, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            appDelegate.openFile(at: url)
                        }
                    }
                    if !recentFilesStore.recentFiles.isEmpty {
                        Divider()
                        Button("Clear Menu") {
                            recentFilesStore.clear()
                        }
                    }
                }
            }
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appDelegate.openEmptyTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Next Tab") {
                    appDelegate.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .keyboardShortcut(.tab, modifiers: .control)

                Button("Previous Tab") {
                    appDelegate.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .keyboardShortcut(.tab, modifiers: [.control, .shift])

                Divider()

                ForEach(1...9, id: \.self) { index in
                    Button("Show Tab \(index)") {
                        appDelegate.selectTab(at: index - 1)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
                }

                Button("Reload") {
                    appDelegate.reloadActiveDocument()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Divider()

                Button("Find...") {
                    appDelegate.showFindBar()
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    appDelegate.findNext()
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    appDelegate.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Divider()

                Button(editorSettings.menuItemTitle) {
                    appDelegate.openInExternalEditor()
                }
            }
            CommandGroup(after: .toolbar) {
                Button(appearanceSettings.label) {
                    appearanceSettings.cycle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Zoom In") {
                    appDelegate.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    appDelegate.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    appDelegate.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Toggle("Bring to Front on File Change", isOn: $autoRaiseOnFileChange)
            }
        }
        Settings {
            SettingsView()
        }
    }
}
