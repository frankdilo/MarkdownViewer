import SwiftUI

final class RecentFilesStore: ObservableObject {
    static let shared = RecentFilesStore()

    @Published private(set) var recentFiles: [URL] = []
    private let maxRecentFiles = 10
    private let defaultsKey = "recentFiles"

    private init() {
        load()
    }

    func add(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        save()
    }

    func clear() {
        recentFiles = []
        save()
    }

    private func save() {
        let paths = recentFiles.map { $0.path }
        UserDefaults.standard.set(paths, forKey: defaultsKey)
    }

    private func load() {
        if let paths = UserDefaults.standard.stringArray(forKey: defaultsKey) {
            recentFiles = paths.compactMap { URL(fileURLWithPath: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }
}
