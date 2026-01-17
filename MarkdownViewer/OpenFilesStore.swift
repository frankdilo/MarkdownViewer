import SwiftUI

final class OpenFilesStore: ObservableObject {
    static let shared = OpenFilesStore()

    @Published private(set) var openFiles: [URL] = []
    private let defaultsKey = "openFiles"

    private init() {
        load()
    }

    func set(_ urls: [URL]) {
        openFiles = normalize(urls)
        save()
    }

    private func save() {
        let paths = openFiles.map { $0.path }
        UserDefaults.standard.set(paths, forKey: defaultsKey)
    }

    private func load() {
        if let paths = UserDefaults.standard.stringArray(forKey: defaultsKey) {
            openFiles = normalize(paths.map { URL(fileURLWithPath: $0) })
        }
    }

    private func normalize(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for url in urls {
            let path = url.path
            guard !seen.contains(path) else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            seen.insert(path)
            result.append(url)
        }
        return result
    }
}
