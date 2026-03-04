import Foundation

// MARK: - .NET Csproj Parser

/// Parses .csproj files for .NET/C# projects
/// Handles both single projects and solutions with multiple projects
struct CsprojParser {
    
    /// Check if this is a solution file and get project references
    static func parseSolution(at projectPath: String) -> [ProjectDependencyGroup] {
        var projectGroups: [ProjectDependencyGroup] = []
        
        print("[CsprojParser] Starting parse at path: \(projectPath)")
        
        // Look for .sln file
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: projectPath) else {
            print("[CsprojParser] Cannot read directory contents")
            return []
        }
        
        print("[CsprojParser] Directory contents: \(contents)")
        
        let slnFile = contents.first { $0.hasSuffix(".sln") }
        
        print("[CsprojParser] Found sln file: \(slnFile ?? "none")")
        
        if let sln = slnFile {
            // Parse solution file to get project references
            let slnPath = (projectPath as NSString).appendingPathComponent(sln)
            print("[CsprojParser] Parsing solution file: \(slnPath)")
            
            let csprojFiles = parseSolutionProjects(slnPath: slnPath, projectPath: projectPath)
            print("[CsprojParser] Found csproj files: \(csprojFiles)")
            
            // Parse each csproj file
            for csprojPath in csprojFiles {
                print("[CsprojParser] Processing csproj: \(csprojPath)")
                if let group = parseCsprojFile(at: csprojPath) {
                    print("[CsprojParser] Found dependencies in \(group.projectName): \(group.dependencies.count)")
                    projectGroups.append(group)
                } else {
                    print("[CsprojParser] No dependencies found in \(csprojPath)")
                }
            }
        } else {
            // No .sln file - find all csproj files in the directory
            let csprojFiles = contents.filter { $0.hasSuffix(".csproj") }
            
            if csprojFiles.isEmpty {
                // Also check subdirectories for csproj files
                if let subDirs = try? fm.contentsOfDirectory(atPath: projectPath) {
                    for item in subDirs {
                        let subPath = (projectPath as NSString).appendingPathComponent(item)
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: subPath, isDirectory: &isDir), isDir.boolValue {
                            if let subContents = try? fm.contentsOfDirectory(atPath: subPath) {
                                let subCsprojFiles = subContents.filter { $0.hasSuffix(".csproj") }
                                for csproj in subCsprojFiles {
                                    let fullPath = (subPath as NSString).appendingPathComponent(csproj)
                                    if let group = parseCsprojFile(at: fullPath) {
                                        projectGroups.append(group)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // Parse all csproj files found in root
                for csproj in csprojFiles {
                    let fullPath = (projectPath as NSString).appendingPathComponent(csproj)
                    if let group = parseCsprojFile(at: fullPath) {
                        projectGroups.append(group)
                    }
                }
            }
        }
        
        return projectGroups
    }
    
    /// Parse solution file to get project paths
    private static func parseSolutionProjects(slnPath: String, projectPath: String) -> [String] {
        guard let content = try? String(contentsOfFile: slnPath, encoding: .utf8) else {
            print("[CsprojParser] Cannot read sln file content")
            return []
        }
        
        print("[CsprojParser] Sln file content (first 500 chars): \(String(content.prefix(500)))")
        
        var projects: [String] = []
        
        // Look for Project entries: Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "ProjectName", "ProjectPath.csproj", "{GUID}"
        let pattern = #"Project\([^)]+\)\s*=\s*"[^"]+"\s*,\s*"([^"]+\.csproj)""#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsContent = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
            
            print("[CsprojParser] Regex matches found: \(matches.count)")
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: content) {
                    let projectRef = String(content[range])
                    // Normalize Windows-style backslashes to POSIX slashes
                    let normalizedRef = projectRef.replacingOccurrences(of: "\\", with: "/")
                    
                    print("[CsprojParser] Found project reference: \(projectRef)")
                    if projectRef != normalizedRef {
                        print("[CsprojParser] Normalized project reference: \(normalizedRef)")
                    }
                    
                    // Handle relative paths properly using URL resolution
                    let fullPath: String
                    if normalizedRef.hasPrefix("..") {
                        // Resolve relative path correctly
                        let slnDir = (slnPath as NSString).deletingLastPathComponent
                        let baseURL = URL(fileURLWithPath: slnDir)
                        if let resolvedURL = URL(string: normalizedRef, relativeTo: baseURL) {
                            fullPath = resolvedURL.standardizedFileURL.path
                        } else {
                            // Fallback to manual resolution
                            fullPath = resolveRelativePath(base: slnDir, relative: normalizedRef)
                        }
                    } else {
                        fullPath = (projectPath as NSString).appendingPathComponent(normalizedRef)
                    }
                    
                    print("[CsprojParser] Full path: \(fullPath)")
                    
                    // Verify the file exists before adding
                    if FileManager.default.fileExists(atPath: fullPath) {
                        print("[CsprojParser] File exists, adding: \(fullPath)")
                        projects.append(fullPath)
                    } else {
                        print("[CsprojParser] File does NOT exist: \(fullPath)")
                    }
                }
            }
        }
        
        return projects
    }
    
    /// Resolve relative path manually (handles .. and nested paths)
    private static func resolveRelativePath(base: String, relative: String) -> String {
        var components = relative.split(separator: "/").map(String.init)
        var result = base
        
        while !components.isEmpty {
            let comp = components.removeFirst()
            if comp == ".." {
                result = (result as NSString).deletingLastPathComponent
            } else if comp != "." {
                result = (result as NSString).appendingPathComponent(comp)
            }
        }
        
        return result
    }
    
    /// Parse a single csproj file
    private static func parseCsprojFile(at csprojPath: String) -> ProjectDependencyGroup? {
        guard let fileData = FileManager.default.contents(atPath: csprojPath) else {
            return nil
        }
        
        // Try to parse as XML
        let projectName = (csprojPath as NSString).lastPathComponent
            .replacingOccurrences(of: ".csproj", with: "")
        
        var regularDeps: [Dependency] = []
        
        // First, try to read as string and remove BOM if present
        if var content = String(data: fileData, encoding: .utf8) {
            // Remove UTF-8 BOM if present (the ﻿ character at the start)
            if content.hasPrefix("\u{FEFF}") {
                content = String(content.dropFirst(1))
            }
            
            // Try XML parsing with the cleaned content
            if let data = content.data(using: .utf8),
               let xmlDoc = try? XMLDocument(data: data, options: []),
               let root = xmlDoc.rootElement() {
                
                // Find PackageReference elements
                let packageRefs = root.elements(forName: "PackageReference")
                
                for ref in packageRefs {
                    guard let name = ref.attribute(forName: "Include")?.stringValue else {
                        continue
                    }
                    
                    // Version is optional - use * if not specified
                    let version = ref.attribute(forName: "Version")?.stringValue ?? "*"
                    
                    // Check if it's a development dependency
                    let isDev = ref.attribute(forName: "PrivateAssets")?.stringValue == "all"
                    
                    let dependency = Dependency(
                        name: name,
                        version: version,
                        type: isDev ? .dev : .regular,
                        source: .nuget
                    )
                    regularDeps.append(dependency)
                }
                
                // Also find FrameworkReference elements (ASP.NET Core shared framework)
                let frameworkRefs = root.elements(forName: "FrameworkReference")
                
                for ref in frameworkRefs {
                    guard let name = ref.attribute(forName: "Include")?.stringValue else {
                        continue
                    }
                    
                    let version = ref.attribute(forName: "Version")?.stringValue ?? "*"
                    
                    let dependency = Dependency(
                        name: name,
                        version: version,
                        type: .regular,
                        source: .nuget
                    )
                    regularDeps.append(dependency)
                }
                
                // Find ProjectReference elements (internal project references)
                let projectRefs = root.elements(forName: "ProjectReference")
                
                for ref in projectRefs {
                    guard let name = ref.attribute(forName: "Include")?.stringValue else {
                        continue
                    }
                    
                    // Extract project name from path
                    let projectName = (name as NSString).lastPathComponent
                        .replacingOccurrences(of: ".csproj", with: "")
                    
                    let dependency = Dependency(
                        name: projectName,
                        version: "*",
                        type: .transitive,
                        source: .nuget
                    )
                    regularDeps.append(dependency)
                }
            }
            
            // Fallback to regex parsing if XML fails or returns empty
            if regularDeps.isEmpty {
                guard let fallbackContent = String(data: fileData, encoding: .utf8) else {
                    return nil
                }
                
                // Parse using regex as fallback
                let pattern = #"<PackageReference\s+Include="([^"]+)"(?:\s+Version="([^"]+)")?"#
                
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsContent = fallbackContent as NSString
                    let matches = regex.matches(in: fallbackContent, options: [], range: NSRange(location: 0, length: nsContent.length))
                    
                    for match in matches {
                        if let nameRange = Range(match.range(at: 1), in: fallbackContent) {
                            let name = String(fallbackContent[nameRange])
                            var version = "*"
                            
                            if match.range(at: 2).location != NSNotFound,
                               let verRange = Range(match.range(at: 2), in: fallbackContent) {
                                version = String(fallbackContent[verRange])
                            }
                            
                            let dependency = Dependency(
                                name: name,
                                version: version,
                                type: .regular,
                                source: .nuget
                            )
                            regularDeps.append(dependency)
                        }
                    }
                }
            }
            
            guard !regularDeps.isEmpty else { return nil }
            
            return ProjectDependencyGroup(
                projectName: projectName,
                dependencies: regularDeps.sorted { $0.name.lowercased() < $1.name.lowercased() }
            )
        }
        
        return nil
        
        /// Parse csproj file directly (single project mode)
        func parse(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
            guard let group = parseSolution(at: projectPath).first else {
                return nil
            }
            
            let regular = group.dependencies.filter { $0.type == .regular }
            let dev = group.dependencies.filter { $0.type == .dev }
            
            return (regular, dev)
        }
    }
}
