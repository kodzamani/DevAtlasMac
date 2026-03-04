import Foundation

// MARK: - Project Dependencies Result

/// Complete result containing all dependencies for a project
struct ProjectDependencies {
    var directDependencies: [Dependency]
    var devDependencies: [Dependency]
    var projectGroups: [ProjectDependencyGroup]
    
    var totalCount: Int {
        directDependencies.count + devDependencies.count + projectGroups.flatMap { $0.dependencies }.count
    }
    
    var hasDependencies: Bool {
        !directDependencies.isEmpty || !devDependencies.isEmpty || !projectGroups.isEmpty
    }
    
    static var empty: ProjectDependencies {
        ProjectDependencies(
            directDependencies: [],
            devDependencies: [],
            projectGroups: []
        )
    }
}
