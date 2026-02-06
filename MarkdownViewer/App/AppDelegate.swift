import AppKit
import SwiftUI
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [ViewerWindowController] = []
    private let openFilesStore = OpenFilesStore.shared
    private var windowCloseObserver: Any?
    private var keyDownMonitor: Any?
    private var didRestoreOpenFiles = false
    private var isTerminating = false

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openFile(at: url)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
        NSApplication.shared.activate(ignoringOtherApps: true)
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            self?.handleWindowWillClose(window)
        }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.control) else { return event }
            guard !flags.contains(.command), !flags.contains(.option) else { return event }
            guard event.keyCode == 48 else { return event }
            guard self.activeDocumentWindow() != nil else { return event }
            if flags.contains(.shift) {
                self.selectPreviousTab()
            } else {
                self.selectNextTab()
            }
            return nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.restoreOpenFilesIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openEmptyTab()
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        persistOpenFilesFromWindows()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        if !isTerminating {
            persistOpenFilesFromWindows()
        }
        if let windowCloseObserver {
            NotificationCenter.default.removeObserver(windowCloseObserver)
        }
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
    }

    func openFileFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            openFile(at: url)
        }
    }

    func openFile(at url: URL) {
        if let documentState = reusableEmptyDocumentState() {
            documentState.loadFile(at: url)
            focusWindow(for: documentState)
            return
        }

        openInNewTab(url: url)
    }

    func openEmptyTab() {
        openInNewTab(url: nil)
    }

    func reloadActiveDocument() {
        activeDocumentState()?.reload()
    }

    func zoomIn() {
        activeDocumentState()?.zoomIn()
    }

    func zoomOut() {
        activeDocumentState()?.zoomOut()
    }

    func resetZoom() {
        activeDocumentState()?.resetZoom()
    }

    func showFindBar() {
        activeDocumentState()?.showFindBar()
    }

    func findNext() {
        activeDocumentState()?.findNext()
    }

    func findPrevious() {
        activeDocumentState()?.findPrevious()
    }

    func openInExternalEditor() {
        guard let url = activeDocumentState()?.currentURL else {
            NSSound.beep()
            return
        }
        let settings = ExternalEditorSettings.shared
        if let editorURL = settings.editorAppURL {
            if FileManager.default.fileExists(atPath: editorURL.path) {
                NSWorkspace.shared.open(
                    [url],
                    withApplicationAt: editorURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            } else {
                let alert = NSAlert()
                alert.messageText = "Editor Not Found"
                alert.informativeText = "\(settings.editorDisplayName) could not be found at \(editorURL.path)."
                alert.addButton(withTitle: "Choose Editor\u{2026}")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .warning
                if alert.runModal() == .alertFirstButtonReturn {
                    promptForEditor(thenOpen: url)
                }
            }
        } else {
            promptForEditor(thenOpen: url)
        }
    }

    private func promptForEditor(thenOpen fileURL: URL) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an editor application for Markdown files"
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let editorURL = panel.url else { return }
        ExternalEditorSettings.shared.setEditor(url: editorURL)
        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: editorURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    func selectNextTab() {
        activeDocumentWindow()?.selectNextTab(nil)
    }

    func selectPreviousTab() {
        activeDocumentWindow()?.selectPreviousTab(nil)
    }

    func selectTab(at index: Int) {
        guard let window = activeDocumentWindow() else { return }
        let tabs = tabGroupWindows(for: window)
        guard tabs.indices.contains(index) else { return }
        tabs[index].makeKeyAndOrderFront(nil)
    }

    private func activeDocumentState() -> DocumentState? {
        if let state = NSApplication.shared.keyWindow?.documentState {
            return state
        }
        if let state = NSApplication.shared.mainWindow?.documentState {
            return state
        }
        return NSApplication.shared.windows.compactMap(\.documentState).first
    }

    private func activeDocumentWindow() -> NSWindow? {
        if let window = NSApplication.shared.keyWindow, window.documentState != nil {
            return window
        }
        if let window = NSApplication.shared.mainWindow, window.documentState != nil {
            return window
        }
        return NSApplication.shared.windows.first { $0.documentState != nil }
    }

    private func reusableEmptyDocumentState() -> DocumentState? {
        if let active = activeDocumentState(), active.currentURL == nil {
            return active
        }
        return NSApplication.shared.windows
            .compactMap(\.documentState)
            .first { $0.currentURL == nil }
    }

    private func focusWindow(for documentState: DocumentState) {
        if let window = NSApplication.shared.windows.first(where: { $0.documentState === documentState }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func tabGroupWindows(for window: NSWindow) -> [NSWindow] {
        let tabs = window.tabbedWindows ?? []
        return tabs.isEmpty ? [window] : tabs
    }

    private func restoreOpenFilesIfNeeded() {
        guard !didRestoreOpenFiles else { return }
        let urls = openFilesStore.openFiles
        guard !urls.isEmpty else { return }
        guard NSApplication.shared.windows.contains(where: { $0.documentState != nil }) else {
            DispatchQueue.main.async { [weak self] in
                self?.restoreOpenFilesIfNeeded()
            }
            return
        }
        didRestoreOpenFiles = true
        let existing = Set(currentOpenFileURLs().map { $0.path })
        for url in urls where !existing.contains(url.path) {
            openFile(at: url)
        }
    }

    private func handleWindowWillClose(_ window: NSWindow) {
        guard window.documentState != nil else { return }
        if isTerminating { return }
        let documentWindows = NSApplication.shared.windows.filter { $0.documentState != nil }
        if documentWindows.count == 1 && documentWindows.first === window {
            openFilesStore.set(currentOpenFileURLs())
            return
        }
        let remaining = documentWindows
            .filter { $0 !== window }
            .compactMap { $0.documentState?.currentURL }
        openFilesStore.set(remaining)
    }

    private func persistOpenFilesFromWindows() {
        openFilesStore.set(currentOpenFileURLs())
    }

    private func currentOpenFileURLs() -> [URL] {
        NSApplication.shared.windows.compactMap { $0.documentState?.currentURL }
    }

    private func openInNewTab(url: URL?) {
        let documentState = DocumentState()
        if let url {
            documentState.loadFile(at: url)
        }

        openWindow(with: documentState)
    }

    private func openWindow(with documentState: DocumentState) {
        let contentView = ContentView(documentState: documentState)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 600, height: 400))
        window.tabbingMode = .preferred
        window.title = documentState.title
        window.documentState = documentState

        let windowController = ViewerWindowController(window: window)
        window.delegate = windowController
        windowController.onClose = { [weak self, weak windowController] in
            guard let windowController else { return }
            self?.windowControllers.removeAll { $0 === windowController }
        }
        if let tabGroupWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            tabGroupWindow.addTabbedWindow(window, ordered: .above)
        }
        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        windowControllers.append(windowController)
    }
}

final class ViewerWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
