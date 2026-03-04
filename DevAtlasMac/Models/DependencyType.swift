import Foundation

// MARK: - Dependency Type

enum DependencyType: String, Codable, CaseIterable {
    case regular
    case dev
    case peer
    case optional
    case transitive
}
