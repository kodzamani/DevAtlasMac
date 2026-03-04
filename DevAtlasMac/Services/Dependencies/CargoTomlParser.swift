import Foundation

// MARK: - Cargo.toml Parser

/// Parses Cargo.toml files for Rust projects
struct CargoTomlParser {
    
    /// Parse Cargo.toml and extract dependencies
    static func parse(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        let cargoPath = (projectPath as NSString).appendingPathComponent("Cargo.toml")
        
        guard let content = try? String(contentsOfFile: cargoPath, encoding: .utf8) else {
            return nil
        }
        
        var regularDeps: [Dependency] = []
        var devDeps: [Dependency] = []
        
        let lines = content.components(separatedBy: .newlines)
        var currentSection: String = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect section headers
            if trimmed.hasPrefix("[dependencies]") {
                currentSection = "dependencies"
                continue
            } else if trimmed.hasPrefix("[dev-dependencies]") {
                currentSection = "dev-dependencies"
                continue
            } else if trimmed.hasPrefix("[build-dependencies]") {
                currentSection = "build-dependencies"
                continue
            } else if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = ""
                continue
            }
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse dependency lines
            if currentSection == "dependencies" || currentSection == "dev-dependencies" {
                if let dep = parseDependencyLine(trimmed) {
                    let depType: DependencyType = currentSection == "dev-dependencies" ? .dev : .regular
                    let dependency = Dependency(
                        name: dep.name,
                        version: dep.version,
                        type: depType,
                        source: .cargo
                    )
                    
                    if currentSection == "dev-dependencies" {
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
        // Format: package-name = "1.0.0" or package-name = { version = "1.0.0", features = [...] }
        
        // Handle inline tables: package = { version = "1.0", features = ["feat1"] }
        if line.contains("{") {
            return parseInlineTableDependency(line)
        }
        
        // Handle simple version: package-name = "1.0.0"
        let parts = line.split(separator: "=", maxSplits: 1)
        guard parts.count >= 2 else { return nil }
        
        let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
        var version = String(parts[1])
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\"", with: "")
        
        if name.isEmpty {
            return nil
        }
        
        // Handle version specifications like "1.0", "^1.0", etc.
        if version.isEmpty || version == "*" {
            version = "*"
        }
        
        return (name, version)
    }
    
    /// Parse inline table dependency
    private static func parseInlineTableDependency(_ line: String) -> (name: String, version: String)? {
        // Extract name before = 
        let nameParts = line.split(separator: "=", maxSplits: 1)
        guard nameParts.count >= 2 else { return nil }
        
        let name = String(nameParts[0]).trimmingCharacters(in: .whitespaces)
        
        // Extract version from inline table
        let tableContent = String(nameParts[1])
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        
        var version = "*"
        
        // Look for version = "x.x.x"
        let versionPattern = #"version\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: versionPattern, options: []),
           let match = regex.firstMatch(in: tableContent, range: NSRange(location: 0, length: tableContent.count)),
           let range = Range(match.range(at: 1), in: tableContent) {
            version = String(tableContent[range])
        }
        
        // Look for git = ...
        if tableContent.contains("git =") && version == "*" {
            version = "git"
        }
        
        // Look for path = ...
        if tableContent.contains("path =") && version == "*" {
            version = "local"
        }
        
        return (name, version)
    }
}
