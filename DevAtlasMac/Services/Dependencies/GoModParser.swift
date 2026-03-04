import Foundation

// MARK: - Go.mod Parser

/// Parses go.mod files for Go projects
struct GoModParser {
    
    /// Parse go.mod and extract dependencies
    static func parse(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        let goModPath = (projectPath as NSString).appendingPathComponent("go.mod")
        
        guard let content = try? String(contentsOfFile: goModPath, encoding: .utf8) else {
            return nil
        }
        
        var regularDeps: [Dependency] = []
        var devDeps: [Dependency] = []
        
        let lines = content.components(separatedBy: .newlines)
        var currentSection: String = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect section headers
            if trimmed.hasPrefix("require (") || trimmed == "require" {
                currentSection = "require"
                continue
            } else if trimmed == ")" && currentSection == "require" {
                currentSection = ""
                continue
            }
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") {
                continue
            }
            
            // Skip module and go version declarations
            if trimmed.hasPrefix("module ") || 
               trimmed.hasPrefix("go ") ||
               trimmed.hasPrefix("exclude ") ||
               trimmed.hasPrefix("replace ") ||
               trimmed.hasPrefix("retract ") {
                continue
            }
            
            // Parse dependency lines
            if currentSection == "require" || currentSection.isEmpty {
                if let dep = parseDependencyLine(trimmed) {
                    let dependency = Dependency(
                        name: dep.name,
                        version: dep.version,
                        type: .regular,
                        source: .go
                    )
                    regularDeps.append(dependency)
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
        // Format: module-name v1.2.3 or module-name v1.2.3 // indirect
        let parts = line.split(separator: " ", maxSplits: 2)
        
        guard parts.count >= 2 else { return nil }
        
        let name = String(parts[0])
        var version = String(parts[1])
        
        // Remove v prefix from version
        if version.hasPrefix("v") {
            version = String(version.dropFirst())
        }
        
        // Remove indirect comment marker
        if version.hasPrefix("//") {
            version = version.components(separatedBy: " ")[0]
        }
        
        // Clean version
        version = version.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        if name.isEmpty || version.isEmpty {
            return nil
        }
        
        return (name, version)
    }
}
