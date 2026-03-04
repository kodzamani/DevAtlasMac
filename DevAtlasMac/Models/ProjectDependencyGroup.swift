import Foundation

// MARK: - Project Dependency Group

/// Groups dependencies by project (used for .NET solutions with multiple csproj files)
struct ProjectDependencyGroup: Identifiable, Hashable {
    var id: String { projectName }
    let projectName: String
    var dependencies: [Dependency]
    
    var dependencyCount: Int {
        dependencies.count
    }
}
