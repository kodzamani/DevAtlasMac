import Foundation

/// How the project browser lays out its contents, mirroring Finder's view modes.
enum BrowserViewMode: String, CaseIterable, Identifiable {
    case icons
    case list
    case columns

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .icons: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .columns: return "rectangle.split.3x1"
        }
    }

    var title: String {
        switch self {
        case .icons: return "finder.iconsView".localized
        case .list: return "finder.listView".localized
        case .columns: return "finder.columnsView".localized
        }
    }
}
