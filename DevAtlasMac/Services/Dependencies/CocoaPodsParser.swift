import Foundation

// MARK: - CocoaPods Parser

/// Parses Podfile.lock files for CocoaPods dependencies
struct CocoaPodsParser {
    
    /// Parse Podfile.lock and extract dependencies
    static func parse(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        let podfileLockPath = (projectPath as NSString).appendingPathComponent("Podfile.lock")
        
        guard let content = try? String(contentsOfFile: podfileLockPath, encoding: .utf8) else {
            return nil
        }
        
        var regularDeps: [Dependency] = []
        var devDeps: [Dependency] = []
        
        let lines = content.components(separatedBy: .newlines)
        var currentSection: String = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect section headers
            if trimmed.hasPrefix("PODS:") || trimmed == "PODS" {
                currentSection = "pods"
                continue
            } else if trimmed.hasPrefix("DEPENDENCIES:") || trimmed == "DEPENDENCIES" {
                currentSection = "dependencies"
                continue
            } else if trimmed.hasPrefix("EXTERNAL SOURCES:") {
                currentSection = "external"
                continue
            } else if trimmed.hasPrefix("SPEC CHECKSUMS:") ||
                      trimmed.hasPrefix("PODFILE CHECKSUM:") ||
                      trimmed.hasPrefix("COCOAPODS:") {
                currentSection = ""
                continue
            }
            
            // Skip empty lines and special lines
            if trimmed.isEmpty || trimmed.hasPrefix("  - ") || trimmed.hasPrefix("    - ") {
                continue
            }
            
            // Parse pod entries in PODS section
            if currentSection == "pods" {
                // Format: - PodName (1.0.0) or - PodName (1.0.0) (from `path`)
                if trimmed.hasPrefix("- ") {
                    if let dep = parsePodEntry(trimmed) {
                        regularDeps.append(dep)
                    }
                }
            }
            
            // Parse dependency entries in DEPENDENCIES section
            if currentSection == "dependencies" {
                // Format: - PodName (~> 1.0) or - PodName (from `path`)
                if trimmed.hasPrefix("- ") {
                    if let dep = parseDependencyEntry(trimmed) {
                        regularDeps.append(dep)
                    }
                }
            }
        }
        
        // Remove duplicates (prefer version from PODS section)
        var seen = Set<String>()
        regularDeps = regularDeps.filter { dep in
            if seen.contains(dep.name) {
                return false
            }
            seen.insert(dep.name)
            return true
        }
        
        return (
            regularDeps.sorted { $0.name.lowercased() < $1.name.lowercased() },
            devDeps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        )
    }
    
    /// Parse a pod entry from PODS section
    private static func parsePodEntry(_ line: String) -> Dependency? {
        // Format: - PodName (1.0.0) or - PodName (1.0.0) (from `path`)
        
        // Remove leading "- "
        var content = line
        if content.hasPrefix("- ") {
            content = String(content.dropFirst(2))
        }
        
        // Extract version from parentheses
        var name = content
        var version = "*"
        
        if let parenStart = content.firstIndex(of: "("),
           let parenEnd = content.firstIndex(of: ")") {
            let versionStr = content[content.index(after: parenStart)..<parenEnd]
            version = String(versionStr)
            
            // Get name before parenthesis
            name = String(content[..<parenStart]).trimmingCharacters(in: .whitespaces)
        }
        
        // Handle subspecs (e.g., Alamofire/Network)
        if let slashIndex = name.firstIndex(of: "/") {
            name = String(name[..<slashIndex])
        }
        
        guard !name.isEmpty else { return nil }
        
        return Dependency(
            name: name,
            version: version,
            type: .regular,
            source: .cocoapods
        )
    }
    
    /// Parse a dependency entry from DEPENDENCIES section
    private static func parseDependencyEntry(_ line: String) -> Dependency? {
        // Format: - PodName (~> 1.0) or - PodName (from `path`)
        
        // Remove leading "- "
        var content = line
        if content.hasPrefix("- ") {
            content = String(content.dropFirst(2))
        }
        
        // Extract version constraint
        var name = content
        var version = "*"
        
        // Handle version constraints like ~> 1.0, >= 1.0, etc.
        if let parenStart = content.firstIndex(of: "("),
           let parenEnd = content.firstIndex(of: ")") {
            let constraint = content[content.index(after: parenStart)..<parenEnd]
            // Only use version if it looks like a version number
            if !constraint.contains("from") && !constraint.contains("path") && !constraint.contains("git") {
                version = String(constraint)
            }
            
            // Get name before parenthesis
            name = String(content[..<parenStart]).trimmingCharacters(in: .whitespaces)
        }
        
        // Handle subspecs
        if let slashIndex = name.firstIndex(of: "/") {
            name = String(name[..<slashIndex])
        }
        
        guard !name.isEmpty else { return nil }
        
        return Dependency(
            name: name,
            version: version,
            type: .regular,
            source: .cocoapods
        )
    }
}
