import Foundation

// MARK: - Dependency Model

/// Represents a single package/dependency
struct Dependency: Identifiable, Codable, Hashable {
    var id: String { "\(name)-\(version)" }
    let name: String
    let version: String
    let type: DependencyType
    let source: DependencySource
    var latestVersion: String? = nil
    var repositoryURL: String? = nil
    
    var displayVersion: String {
        if version.isEmpty || version == "*" {
            return "latest"
        }
        return version
    }
    
    var isUpgradeable: Bool {
        guard let latest = latestVersion,
              !latest.isEmpty,
              !version.isEmpty,
              version != "*" else { return false }
        return latest != version
    }
}
