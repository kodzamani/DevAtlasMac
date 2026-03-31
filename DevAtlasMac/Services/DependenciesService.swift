import Foundation

// MARK: - Dependencies Service

/// Main service that orchestrates all dependency parsers
actor DependenciesService {
    
    /// Get dependencies for a project based on its type
    static func getDependencies(for project: ProjectInfo) async -> ProjectDependencies {
        let projectPath = project.path
        let projectType = project.projectType
        
        // Route to appropriate parser based on project type
        switch projectType {
        case "Node.js", "React", "React Native", "Next.js", "Vue", "Angular", "Vite":
            return parseJavaScriptProject(at: projectPath, type: projectType)
            
        case "Flutter":
            return parseFlutterProject(at: projectPath, type: projectType)
            
        case "Go":
            return parseGoProject(at: projectPath, type: projectType)
            
        case "Rust":
            return parseRustProject(at: projectPath, type: projectType)
            
        case ".NET", ".NET Solution":
            return parseDotNetProject(at: projectPath, type: projectType)
            
        case "iOS", "Swift", "Xcode", "Xcode Workspace":
            return parseSwiftProject(at: projectPath, type: projectType)
            
        default:
            // Try all parsers and merge results
            return parseGenericProject(at: projectPath, type: projectType)
        }
    }
    
    // MARK: - JavaScript/Node.js
    
    private static func parseJavaScriptProject(at path: String, type _: String) -> ProjectDependencies {
        guard let deps = PackageJsonParser.parse(at: path) else {
            return .empty
        }
        
        return ProjectDependencies(
            directDependencies: deps.regular,
            devDependencies: deps.dev,
            projectGroups: []
        )
    }
    
    // MARK: - Flutter/Dart
    
    private static func parseFlutterProject(at path: String, type _: String) -> ProjectDependencies {
        guard let deps = PubspecParser.parse(at: path) else {
            return .empty
        }
        
        return ProjectDependencies(
            directDependencies: deps.regular,
            devDependencies: deps.dev,
            projectGroups: []
        )
    }
    
    // MARK: - Go
    
    private static func parseGoProject(at path: String, type _: String) -> ProjectDependencies {
        guard let deps = GoModParser.parse(at: path) else {
            return .empty
        }
        
        return ProjectDependencies(
            directDependencies: deps.regular,
            devDependencies: deps.dev,
            projectGroups: []
        )
    }
    
    // MARK: - Rust
    
    private static func parseRustProject(at path: String, type _: String) -> ProjectDependencies {
        guard let deps = CargoTomlParser.parse(at: path) else {
            return .empty
        }
        
        return ProjectDependencies(
            directDependencies: deps.regular,
            devDependencies: deps.dev,
            projectGroups: []
        )
    }
    
    // MARK: - .NET
    
    private static func parseDotNetProject(at path: String, type _: String) -> ProjectDependencies {
        let projectGroups = CsprojParser.parseSolution(at: path)
        
        if projectGroups.isEmpty {
            return .empty
        }
        
        // Combine all dependencies from project groups
        var allRegular: [Dependency] = []
        var allDev: [Dependency] = []
        
        for group in projectGroups {
            allRegular.append(contentsOf: group.dependencies.filter { $0.type == .regular })
            allDev.append(contentsOf: group.dependencies.filter { $0.type == .dev })
        }
        
        return ProjectDependencies(
            directDependencies: allRegular,
            devDependencies: allDev,
            projectGroups: projectGroups
        )
    }
    
    // MARK: - Swift (SPM, CocoaPods, Carthage)
    
    private static func parseSwiftProject(at path: String, type _: String) -> ProjectDependencies {
        var allRegular: [Dependency] = []
        var allDev: [Dependency] = []
        
        // 1. Parse Swift Package Manager dependencies
        if let spmDeps = SwiftPackageParser.parse(at: path) {
            allRegular.append(contentsOf: spmDeps.regular)
            allDev.append(contentsOf: spmDeps.dev)
        }
        
        // 2. Parse CocoaPods dependencies
        if let podsDeps = CocoaPodsParser.parse(at: path) {
            // Merge without duplicates
            for dep in podsDeps.regular {
                if !allRegular.contains(where: { $0.name == dep.name }) {
                    allRegular.append(dep)
                }
            }
        }
        
        // 3. Parse Carthage dependencies
        if let carthageDeps = CarthageParser.parse(at: path) {
            // Merge without duplicates
            for dep in carthageDeps.regular {
                if !allRegular.contains(where: { $0.name == dep.name }) {
                    allRegular.append(dep)
                }
            }
        }
        
        if allRegular.isEmpty && allDev.isEmpty {
            return .empty
        }
        
        return ProjectDependencies(
            directDependencies: allRegular,
            devDependencies: allDev,
            projectGroups: []
        )
    }
    
    // MARK: - Generic (try all parsers)
    
    private static func parseGenericProject(at path: String, type _: String) -> ProjectDependencies {
        var allRegular: [Dependency] = []
        var allDev: [Dependency] = []
        var projectGroups: [ProjectDependencyGroup] = []
        
        // Try each parser
        if let jsDeps = PackageJsonParser.parse(at: path) {
            allRegular.append(contentsOf: jsDeps.regular)
            allDev.append(contentsOf: jsDeps.dev)
        }
        
        if let flutterDeps = PubspecParser.parse(at: path) {
            allRegular.append(contentsOf: flutterDeps.regular)
            allDev.append(contentsOf: flutterDeps.dev)
        }
        
        if let goDeps = GoModParser.parse(at: path) {
            allRegular.append(contentsOf: goDeps.regular)
            allDev.append(contentsOf: goDeps.dev)
        }
        
        if let rustDeps = CargoTomlParser.parse(at: path) {
            allRegular.append(contentsOf: rustDeps.regular)
            allDev.append(contentsOf: rustDeps.dev)
        }
        
        let dotNetGroups = CsprojParser.parseSolution(at: path)
        projectGroups.append(contentsOf: dotNetGroups)
        
        if let spmDeps = SwiftPackageParser.parse(at: path) {
            allRegular.append(contentsOf: spmDeps.regular)
            allDev.append(contentsOf: spmDeps.dev)
        }
        
        if let podsDeps = CocoaPodsParser.parse(at: path) {
            for dep in podsDeps.regular {
                if !allRegular.contains(where: { $0.name == dep.name }) {
                    allRegular.append(dep)
                }
            }
        }
        
        if let carthageDeps = CarthageParser.parse(at: path) {
            for dep in carthageDeps.regular {
                if !allRegular.contains(where: { $0.name == dep.name }) {
                    allRegular.append(dep)
                }
            }
        }
        
        if allRegular.isEmpty && allDev.isEmpty && projectGroups.isEmpty {
            return .empty
        }
        
        return ProjectDependencies(
            directDependencies: allRegular.sorted { $0.name.lowercased() < $1.name.lowercased() },
            devDependencies: allDev.sorted { $0.name.lowercased() < $1.name.lowercased() },
            projectGroups: projectGroups
        )
    }
}
