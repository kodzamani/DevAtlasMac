import Foundation

// MARK: - Carthage Parser

/// Parses Cartfile.resolved files for Carthage dependencies
struct CarthageParser {
    
    /// Parse Cartfile.resolved and extract dependencies
    static func parse(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        let cartfileResolvedPath = (projectPath as NSString).appendingPathComponent("Cartfile.resolved")
        
        guard let content = try? String(contentsOfFile: cartfileResolvedPath, encoding: .utf8) else {
            return nil
        }
        
        var regularDeps: [Dependency] = []
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse dependency entries
            // Format: github "User/Repo" "version" or git "url" "version"
            if let dep = parseDependencyLine(trimmed) {
                regularDeps.append(dep)
            }
        }
        
        return (
            regularDeps.sorted { $0.name.lowercased() < $1.name.lowercased() },
            []
        )
    }
    
    /// Parse a single dependency line
    private static func parseDependencyLine(_ line: String) -> Dependency? {
        // Handle github format: github "User/Repo" "version"
        let githubPattern = #"github\s+"([^"]+)"\s+"([^"]+)""#
        
        if let regex = try? NSRegularExpression(pattern: githubPattern, options: []),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)),
           let repoRange = Range(match.range(at: 1), in: line),
           let versionRange = Range(match.range(at: 2), in: line) {
            
            let repo = String(line[repoRange])
            let version = String(line[versionRange])
            
            return Dependency(
                name: repo,
                version: version,
                type: .regular,
                source: .carthage
            )
        }
        
        // Handle git format: git "url" "version"
        let gitPattern = #"git\s+"([^"]+)"\s+"([^"]+)""#
        
        if let regex = try? NSRegularExpression(pattern: gitPattern, options: []),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)),
           let urlRange = Range(match.range(at: 1), in: line),
           let versionRange = Range(match.range(at: 2), in: line) {
            
            let url = String(line[urlRange])
            let version = String(line[versionRange])
            
            // Extract name from URL
            let name = extractNameFromGitURL(url)
            
            return Dependency(
                name: name,
                version: version,
                type: .regular,
                source: .carthage
            )
        }
        
        // Handle branch format: github "User/Repo" "branchName"
        let branchPattern = #"github\s+"([^"]+)"\s+"([^"]+)""#
        
        if let regex = try? NSRegularExpression(pattern: branchPattern, options: []),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: line.count)),
           let repoRange = Range(match.range(at: 1), in: line),
           let branchRange = Range(match.range(at: 2), in: line) {
            
            let repo = String(line[repoRange])
            let branch = String(line[branchRange])
            
            // Check if it looks like a version or branch
            if !branch.contains(".") && !branch.allSatisfy({ $0.isHexDigit }) {
                // It's likely a branch name
                return Dependency(
                    name: repo,
                    version: "branch:\(branch)",
                    type: .regular,
                    source: .carthage
                )
            }
        }
        
        return nil
    }
    
    /// Extract package name from git URL
    private static func extractNameFromGitURL(_ url: String) -> String {
        // Handle various git URL formats
        
        // SSH format: git@github.com:User/Repo.git
        if url.hasPrefix("git@") {
            let afterColon = url.components(separatedBy: ":").last ?? url
            return extractRepoName(from: afterColon)
        }
        
        // HTTPS format: https://github.com/User/Repo.git
        if url.contains("github.com") {
            return extractRepoName(from: url)
        }
        
        // Try to get last component
        let components = url.components(separatedBy: "/")
        if let last = components.last {
            return last.replacingOccurrences(of: ".git", with: "")
        }
        
        return url
    }
    
    /// Extract repository name from URL or path
    private static func extractRepoName(from input: String) -> String {
        var cleaned = input
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "git://", with: "")
            .replacingOccurrences(of: ".git", with: "")
        
        // Get the last component
        let components = cleaned.components(separatedBy: "/")
        if let last = components.last {
            cleaned = last
        }
        
        return cleaned
    }
}
