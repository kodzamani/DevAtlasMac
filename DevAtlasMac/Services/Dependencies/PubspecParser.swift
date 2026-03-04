import Foundation

// MARK: - Pubspec.yaml Parser

/// Parses pubspec.yaml files for Flutter/Dart projects
struct PubspecParser {
    
    /// Parse pubspec.yaml and extract dependencies
    static func parse(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        let pubspecPath = (projectPath as NSString).appendingPathComponent("pubspec.yaml")
        
        guard let content = try? String(contentsOfFile: pubspecPath, encoding: .utf8) else {
            // Also try pubspec.yml
            let pubspecYmlPath = (projectPath as NSString).appendingPathComponent("pubspec.yml")
            guard let content = try? String(contentsOfFile: pubspecYmlPath, encoding: .utf8) else {
                return nil
            }
            return parseYamlContent(content)
        }
        
        return parseYamlContent(content)
    }
    
    private static func parseYamlContent(_ content: String) -> (regular: [Dependency], dev: [Dependency])? {
        var regularDeps: [Dependency] = []
        var devDeps: [Dependency] = []
        
        let lines = content.components(separatedBy: .newlines)
        var currentSection: String = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect section headers
            if trimmed.hasPrefix("dependencies:") {
                currentSection = "dependencies"
                continue
            } else if trimmed.hasPrefix("dev_dependencies:") {
                currentSection = "dev_dependencies"
                continue
            } else if trimmed.hasPrefix("dependency_overrides:") {
                currentSection = "dependency_overrides"
                continue
            }
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse dependency lines
            if currentSection == "dependencies" || currentSection == "dev_dependencies" {
                // Skip nested sections (sdk, flutter)
                if trimmed.hasPrefix("sdk:") || trimmed.hasPrefix("flutter:") {
                    continue
                }
                
                // Parse dependency like: package_name: ^1.0.0 or package_name: {sdk: flutter}
                if let dep = parseDependencyLine(trimmed) {
                    let depType: DependencyType = currentSection == "dev_dependencies" ? .dev : .regular
                    let dependency = Dependency(
                        name: dep.name,
                        version: dep.version,
                        type: depType,
                        source: .pub
                    )
                    
                    if currentSection == "dev_dependencies" {
                        devDeps.append(dependency)
                    } else {
                        regularDeps.append(dependency)
                    }
                }
            }
        }
        
        return (
            regularDeps.sorted { $0.name.lowercased() < $1.name.lowercased() },
            devDeps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        )
    }
    
    /// Parse a single dependency line
    private static func parseDependencyLine(_ line: String) -> (name: String, version: String)? {
        // Format: package_name: version or package_name:
        let parts = line.split(separator: ":", maxSplits: 1)
        
        guard parts.count >= 1 else { return nil }
        
        let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
        
        // Skip if name is empty or looks like a section header
        if name.isEmpty || name.hasPrefix(" ") || name.contains("#") {
            return nil
        }
        
        var version = "*"
        
        if parts.count > 1 {
            var versionPart = String(parts[1]).trimmingCharacters(in: .whitespaces)
            
            // Handle inline objects like {sdk: flutter, path: ..}
            if versionPart.hasPrefix("{") {
                versionPart = versionPart
                    .replacingOccurrences(of: "{", with: "")
                    .replacingOccurrences(of: "}", with: "")
                
                // Extract path if available
                if let pathMatch = versionPart.range(of: "path:") {
                    let afterPath = versionPart[pathMatch.upperBound...]
                        .trimmingCharacters(in: .whitespaces)
                    if !afterPath.isEmpty {
                        return (name, "path:\(afterPath)")
                    }
                }
                
                // Extract git if available
                if versionPart.contains("git:") {
                    return (name, "git")
                }
                
                // Extract hosted if available
                if versionPart.contains("hosted:") {
                    return (name, "hosted")
                }
                
                version = "*"
            } else {
                // Clean version string
                version = versionPart
                    .replacingOccurrences(of: "^", with: "")
                    .replacingOccurrences(of: "~", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"\'"))
                
                if version.isEmpty {
                    version = "*"
                }
            }
        }
        
        return (name, version)
    }
}
