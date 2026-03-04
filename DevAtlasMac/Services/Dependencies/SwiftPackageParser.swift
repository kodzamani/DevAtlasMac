import Foundation

// MARK: - Swift Package Manager Parser

/// Parses SPM dependencies for Swift/iOS/macOS projects.
/// Priority:
///   1. Package.resolved (JSON) inside any .xcodeproj or .xcworkspace — most reliable
///   2. Package.resolved at the project root (standalone SPM package)
///   3. Package.swift text parsing as a fallback
struct SwiftPackageParser {

    // MARK: - Public Entry Point

    static func parse(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        // 1. Try Package.resolved from Xcode project/workspace paths
        if let deps = parsePackageResolved(at: projectPath), !deps.regular.isEmpty {
            return deps
        }

        // 2. Try Package.swift text parsing (handles multi-line declarations)
        if let deps = parsePackageSwift(at: projectPath), !deps.regular.isEmpty {
            return deps
        }

        return nil
    }

    // MARK: - Package.resolved (JSON) Parser

    /// Searches common Xcode locations for Package.resolved and parses it.
    private static func parsePackageResolved(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        let candidates = resolvedFileCandidates(in: projectPath)

        for resolvedPath in candidates {
            if let deps = parseResolvedFile(at: resolvedPath), !deps.regular.isEmpty {
                return deps
            }
        }
        return nil
    }

    /// Returns all plausible Package.resolved paths under the given project directory.
    private static func resolvedFileCandidates(in projectPath: String) -> [String] {
        var paths: [String] = []

        // Standalone SPM package
        paths.append((projectPath as NSString).appendingPathComponent("Package.resolved"))

        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: projectPath) else { return paths }

        for item in items {
            let itemPath = (projectPath as NSString).appendingPathComponent(item)

            // .xcodeproj / .xcworkspace
            if item.hasSuffix(".xcodeproj") || item.hasSuffix(".xcworkspace") {
                let spmPath = (itemPath as NSString)
                    .appendingPathComponent("project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
                paths.append(spmPath)

                // Also check directly inside workspace
                let direct = (itemPath as NSString)
                    .appendingPathComponent("xcshareddata/swiftpm/Package.resolved")
                paths.append(direct)
            }

            // Nested .xcworkspace inside a folder
            if item.hasSuffix(".xcworkspace") {
                let nested = (itemPath as NSString)
                    .appendingPathComponent("xcshareddata/swiftpm/Package.resolved")
                paths.append(nested)
            }
        }

        return paths
    }

    /// Parses a single Package.resolved JSON file (supports format v1, v2, v3).
    private static func parseResolvedFile(at path: String) -> (regular: [Dependency], dev: [Dependency])? {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let pins = json["pins"] as? [[String: Any]]
        else { return nil }

        var deps: [Dependency] = []

        for pin in pins {
            // v2/v3: identity + location
            // v1: package + repositoryURL
            let identity = pin["identity"] as? String
            let location = pin["location"] as? String
            let repositoryURL = pin["repositoryURL"] as? String  // v1 fallback

            let url = location ?? repositoryURL ?? ""
            let rawName = identity ?? extractPackageName(from: url)
            guard !rawName.isEmpty else { continue }

            // Capitalise first letter to match common conventions
            let name = rawName.prefix(1).uppercased() + rawName.dropFirst()

            var version = "*"
            if let state = pin["state"] as? [String: Any] {
                if let v = state["version"] as? String { version = v }
                else if let b = state["branch"] as? String { version = "branch:\(b)" }
                else if let r = state["revision"] as? String { version = "rev:\(r.prefix(7))" }
            }

            deps.append(Dependency(name: name, version: version, type: .regular, source: .spm, repositoryURL: url.isEmpty ? nil : url))
        }

        guard !deps.isEmpty else { return nil }
        return (deps.sorted { $0.name.lowercased() < $1.name.lowercased() }, [])
    }

    // MARK: - Package.swift Text Parser

    /// Parses Package.swift by collapsing multi-line `.package(url:` declarations.
    private static func parsePackageSwift(at projectPath: String) -> (regular: [Dependency], dev: [Dependency])? {
        let packageSwiftPath = (projectPath as NSString).appendingPathComponent("Package.swift")

        guard let content = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
            return nil
        }

        var regularDeps: [Dependency] = []
        var devDeps: [Dependency] = []

        // Collapse the whole file so multi-line .package(...) becomes one searchable string
        let collapsed = content.replacingOccurrences(of: "\n", with: " ")

        // Match every .package(...) block (greedy enough for typical nesting)
        let packagePattern = #"\.package\s*\([^)]+\)"#
        guard let regex = try? NSRegularExpression(pattern: packagePattern, options: []) else {
            return nil
        }

        let range = NSRange(collapsed.startIndex..., in: collapsed)
        let matches = regex.matches(in: collapsed, range: range)

        for match in matches {
            guard let matchRange = Range(match.range, in: collapsed) else { continue }
            let block = String(collapsed[matchRange])

            if let dep = parsePackageDependency(block) {
                regularDeps.append(Dependency(
                    name: dep.name,
                    version: dep.version,
                    type: .regular,
                    source: .spm,
                    repositoryURL: dep.url.isEmpty ? nil : dep.url
                ))
            }
        }

        guard !regularDeps.isEmpty else { return nil }
        return (
            regularDeps.sorted { $0.name.lowercased() < $1.name.lowercased() },
            devDeps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        )
    }

    // MARK: - Helpers

    /// Extracts name + version + URL from a collapsed `.package(...)` block.
    private static func parsePackageDependency(_ block: String) -> (name: String, version: String, url: String)? {
        // Extract URL
        var url = ""
        let urlPattern = #"url:\s*"([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: urlPattern),
           let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
           let r = Range(match.range(at: 1), in: block) {
            url = String(block[r])
        }
        guard !url.isEmpty else { return nil }

        let name = extractPackageName(from: url)

        var version = "*"

        let patterns: [(String, String)] = [
            (#"from:\s*"([^"]+)""#, ""),
            (#"exact:\s*"([^"]+)""#, ""),
            (#"branch:\s*"([^"]+)""#, "branch:"),
            (#"revision:\s*"([^"]+)""#, "rev:")
        ]

        for (pattern, prefix) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
               let r = Range(match.range(at: 1), in: block) {
                let value = String(block[r])
                if prefix == "rev:" {
                    version = "\(prefix)\(value.prefix(7))"
                } else if prefix.isEmpty {
                    version = value
                } else {
                    version = "\(prefix)\(value)"
                }
                break
            }
        }

        return (name, version, url)
    }

    /// Extracts a human-readable package name from a Git URL.
    private static func extractPackageName(from url: String) -> String {
        let components = url.components(separatedBy: "/")
        if let last = components.last {
            return last
                .replacingOccurrences(of: ".git", with: "")
                .replacingOccurrences(of: ".package", with: "")
        }
        return url
    }
}
