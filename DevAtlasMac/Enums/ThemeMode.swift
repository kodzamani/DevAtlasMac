/// Theme mode options for the app's appearance
enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case light
    case dark
    case system
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "settings.appearance.light".localized
        case .dark: return "settings.appearance.dark".localized
        case .system: return "settings.appearance.system".localized
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}
