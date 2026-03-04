import Foundation

enum ProjectCategory: String, Codable, CaseIterable, Hashable {
    case web = "Web"
    case desktop = "Desktop"
    case mobile = "Mobile"
    case cloud = "Cloud"
    case other = "Other"
}
