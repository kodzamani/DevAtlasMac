import Foundation

// MARK: - Package.json Parser

/// Parses package.json files for JavaScript/Node.js projects
struct PackageJsonParser {
    
    /// Detects lock file to determine package manager
    enum PackageManager: String {
        case npm = "npm"
        case yarn = "yarn"
        case pnpm = "pnpm"
        
        static func detect(in projectPath: String) -> PackageManager {
            let fm = FileManager.default
            
            if fm.fileExists(atPath: (projectPath as NSString).appendingPathComponent("yarn.lock")) {
                return .yarn
            } else if fm.fileExists(atPath: (projectPath as NSString).appendingPathComponent("pnpm-lock.yaml")) {
                return .pnpm
            }
            return .npm
        }
    }
    
    /// Parse package.json and extract dependencies
    static func parse(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        let packageJsonPath = (projectPath as NSString).appendingPathComponent("package.json")
        
        guard let data = FileManager.default.contents(atPath: packageJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let packageManager = PackageManager.detect(in: projectPath)
        let source: DependencySource
        switch packageManager {
        case .npm: source = .npm
        case .yarn: source = .yarn
        case .pnpm: source = .pnpm
        }
        
        var regularDeps: [Dependency] = []
        var devDeps: [Dependency] = []
        
        // Parse regular dependencies
        if let dependencies = json["dependencies"] as? [String: Any] {
            regularDeps = dependencies.map { name, version in
                Dependency(
                    name: name,
                    version: formatVersion(version),
                    type: .regular,
                    source: source
                )
            }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        // Parse dev dependencies
        if let devDependencies = json["devDependencies"] as? [String: Any] {
            devDeps = devDependencies.map { name, version in
                Dependency(
                    name: name,
                    version: formatVersion(version),
                    type: .dev,
                    source: source
                )
            }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        // Parse peer dependencies
        if let peerDependencies = json["peerDependencies"] as? [String: Any] {
            let peerDeps = peerDependencies.map { name, version in
                Dependency(
                    name: name,
                    version: formatVersion(version),
                    type: .peer,
                    source: source
                )
            }
            regularDeps.append(contentsOf: peerDeps.sorted { $0.name.lowercased() < $1.name.lowercased() })
        }
        
        // Parse optional dependencies
        if let optionalDependencies = json["optionalDependencies"] as? [String: Any] {
            let optionalDeps = optionalDependencies.map { name, version in
                Dependency(
                    name: name,
                    version: formatVersion(version),
                    type: .optional,
                    source: source
                )
            }
            regularDeps.append(contentsOf: optionalDeps.sorted { $0.name.lowercased() < $1.name.lowercased() })
        }
        
        return (regularDeps, devDeps)
    }
    
    /// Format version string - handle various formats like ^1.0.0, ~1.0.0, >=1.0.0, etc.
    private static func formatVersion(_ value: Any) -> String {
        if let versionString = value as? String {
            // Remove common prefixes
            var cleaned = versionString
                .replacingOccurrences(of: "^", with: "")
                .replacingOccurrences(of: "~", with: "")
                .replacingOccurrences(of: ">=", with: "")
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "<=", with: "")
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: "=", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            // Handle version ranges like "1.0.0 - 2.0.0"
            if let rangeSeparator = cleaned.firstIndex(of: " ") {
                cleaned = String(cleaned[..<rangeSeparator])
            }
            
            return cleaned
        }
        return "*"
    }
}
