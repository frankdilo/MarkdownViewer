import AppKit

enum AppearanceMode: Int {
    case system = 0
    case light = 1
    case dark = 2
}

final class AppearanceSettings: ObservableObject {
    static let shared = AppearanceSettings()

    @Published var mode: AppearanceMode = .system {
        didSet {
            guard !isLoading else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    private var isLoading = false

    private init() {
        isLoading = true
        let raw = UserDefaults.standard.integer(forKey: "appearanceMode")
        mode = AppearanceMode(rawValue: raw) ?? .system
        isLoading = false
        // NSApp may be nil during early init; defer until the app is ready
        DispatchQueue.main.async { [self] in
            applyAppearance()
        }
    }

    func cycle() {
        switch mode {
        case .system: mode = .light
        case .light: mode = .dark
        case .dark: mode = .system
        }
    }

    var iconName: String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var label: String {
        switch mode {
        case .system: return "Appearance: System"
        case .light: return "Appearance: Light"
        case .dark: return "Appearance: Dark"
        }
    }

    private func applyAppearance() {
        guard let app = NSApp else { return }
        switch mode {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .aqua)
        case .dark:
            app.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
