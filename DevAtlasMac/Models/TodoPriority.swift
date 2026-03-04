import Foundation

enum TodoPriority: String, Codable, Hashable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var displayName: String {
        switch self {
        case .low: return "editor.priority.low".localized
        case .medium: return "editor.priority.medium".localized
        case .high: return "editor.priority.high".localized
        }
    }
}
