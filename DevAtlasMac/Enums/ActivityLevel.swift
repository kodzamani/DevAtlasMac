import Foundation

enum ActivityLevel: String, CaseIterable {
    case high = "High Activity"
    case medium = "Medium Activity"
    case low = "Low Activity"
    
    var localizedName: String {
        switch self {
        case .high: return "stats.activity.high".localized
        case .medium: return "stats.activity.medium".localized
        case .low: return "stats.activity.low".localized
        }
    }
}
