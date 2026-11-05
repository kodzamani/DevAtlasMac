import Foundation

// MARK: - Dependency Source

enum DependencySource: String, Codable, CaseIterable {
    case npm
    case yarn
    case pnpm
    case pub
    case cargo
    case go
    case nuget
    case spm
    case cocoapods
    case carthage
    
    var displayName: String {
        switch self {
        case .npm: return "npm"
        case .yarn: return "Yarn"
        case .pnpm: return "pnpm"
        case .pub: return "pub.dev"
        case .cargo: return "crates.io"
        case .go: return "pkg.go.dev"
        case .nuget: return "NuGet"
        case .spm: return "Swift PM"
        case .cocoapods: return "CocoaPods"
        case .carthage: return "Carthage"
        }
    }
    
}
