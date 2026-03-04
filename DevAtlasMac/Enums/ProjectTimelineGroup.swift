import Foundation
import SwiftUI

enum ProjectTimelineGroup: Int, CaseIterable, Identifiable {
    case today = 0
    case yesterday
    case thisWeek
    case thisMonth
    case older

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .older: return "Older"
        }
    }

    var iconSystemName: String {
        switch self {
        case .today: return "flame.fill"
        case .yesterday: return "calendar.day.timeline.left"
        case .thisWeek: return "calendar.day.timeline.right"
        case .thisMonth: return "calendar.badge.clock"
        case .older: return "archivebox.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .today: return .orange
        case .yesterday: return .blue
        case .thisWeek: return .purple
        case .thisMonth: return .green
        case .older: return .gray
        }
    }

    static func group(for date: Date) -> ProjectTimelineGroup {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return .today
        }

        if calendar.isDateInYesterday(date) {
            return .yesterday
        }

        let weekDifference = calendar.dateComponents([.weekOfYear], from: date, to: now).weekOfYear ?? 0
        if weekDifference == 0 {
            return .thisWeek
        }

        let monthDifference = calendar.dateComponents([.month], from: date, to: now).month ?? 0
        if monthDifference == 0 {
            return .thisMonth
        }

        return .older
    }
}
