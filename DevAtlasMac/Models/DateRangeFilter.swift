import Foundation

enum DateRangeFilter: String, CaseIterable, Identifiable {
    case week = "7 Days"
    case month = "30 Days"
    case year = "Year"
    case allTime = "All Time"
    
    var id: String { self.rawValue }
    
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .allTime: return nil
        }
    }
}
