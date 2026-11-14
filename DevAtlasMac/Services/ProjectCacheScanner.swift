import Foundation

/// Finds the folders a project can regenerate (installed packages, build output, tool caches)
/// and removes them on request.
///
/// A folder only counts when the files next to it prove what it is: `target` beside a
/// `Cargo.toml`, `Pods` beside a `Podfile`. Names that projects also use for their own files
/// (`dist`, `build`, `vendor`) must be git-ignored as well, so nothing tracked is ever offered.
enum ProjectCacheScanner {
    // MARK: - Rules

    private struct Rule {
        let name: String
        let kind: CacheKind
        /// Any one of these must sit beside the folder. `*.ext` matches by extension. Empty means always.
        var siblings: [String] = []
        /// A file the folder itself must hold.
        var contains: String? = nil
        /// The part of the folder that is the cache, when the rest must stay.
        var subpath: String? = nil
        var needsGitIgnore = false
    }

    private static let javaScript = ["package.json"]
    private static let xcode = ["*.xcodeproj", "*.xcworkspace"]
    private static let gradle = ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "gradlew"]
    private static let dotnet = ["*.csproj", "*.fsproj", "*.vbproj"]
    private static let python = ["setup.py", "pyproject.toml"]

    /// Checked in order; the first rule a folder satisfies wins.
    private static let rules: [Rule] = [
        // JavaScript / TypeScript
        Rule(name: "node_modules", kind: .nodeModules),
        Rule(name: ".next", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".nuxt", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".output", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".angular", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".svelte-kit", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".astro", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".parcel-cache", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".turbo", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".expo", kind: .frameworkCache, siblings: javaScript),
        Rule(name: ".vite", kind: .frameworkCache, siblings: javaScript),

        // Swift / Xcode
        Rule(name: ".build", kind: .buildOutput, siblings: ["Package.swift"]),
        Rule(name: "DerivedData", kind: .derivedData, siblings: xcode + ["Package.swift"]),
        Rule(name: "Pods", kind: .packages, siblings: ["Podfile"], needsGitIgnore: true),
        Rule(name: "Carthage", kind: .packages, siblings: ["Cartfile"], subpath: "Build"),

        // Flutter / Dart
        Rule(name: ".dart_tool", kind: .toolCache, siblings: ["pubspec.yaml"]),
        Rule(name: "build", kind: .buildOutput, siblings: ["pubspec.yaml"]),

        // Java / Kotlin / Android
        Rule(name: ".gradle", kind: .toolCache, siblings: gradle),
        Rule(name: "build", kind: .buildOutput, siblings: ["build.gradle", "build.gradle.kts"]),

        // Rust, Maven
        Rule(name: "target", kind: .buildOutput, siblings: ["Cargo.toml", "pom.xml"]),

        // .NET
        Rule(name: "bin", kind: .buildOutput, siblings: dotnet),
        Rule(name: "obj", kind: .buildOutput, siblings: dotnet),

        // Python
        Rule(name: "__pycache__", kind: .toolCache),
        Rule(name: ".pytest_cache", kind: .toolCache),
        Rule(name: ".mypy_cache", kind: .toolCache),
        Rule(name: ".ruff_cache", kind: .toolCache),
        Rule(name: ".tox", kind: .toolCache),
        Rule(name: ".ipynb_checkpoints", kind: .toolCache),
        Rule(name: ".venv", kind: .virtualEnv, contains: "pyvenv.cfg"),
        Rule(name: "venv", kind: .virtualEnv, contains: "pyvenv.cfg"),
        Rule(name: "env", kind: .virtualEnv, contains: "pyvenv.cfg"),

        // PHP, Ruby
        Rule(name: "vendor", kind: .packages, siblings: ["composer.json"], needsGitIgnore: true),
        Rule(name: "vendor", kind: .packages, siblings: ["Gemfile"], subpath: "bundle"),

        // Names projects also use for their own files: only when git ignores them.
        Rule(name: "build", kind: .buildOutput, siblings: xcode, needsGitIgnore: true),
        Rule(name: "build", kind: .buildOutput, siblings: javaScript + python, needsGitIgnore: true),
        Rule(name: "dist", kind: .buildOutput, siblings: javaScript + python, needsGitIgnore: true),
        Rule(name: "out", kind: .buildOutput, siblings: javaScript, needsGitIgnore: true),
        Rule(name: "coverage", kind: .toolCache, siblings: javaScript, needsGitIgnore: true),
        Rule(name: ".nyc_output", kind: .toolCache, siblings: javaScript)
    ]

    private static let rulesByName = Dictionary(grouping: rules, by: \.name)

    /// Bundles and asset folders: never caches, and never worth walking.
    private static let opaqueExtensions: Set<String> = [
        "xcodeproj", "xcworkspace", "xcassets", "xcframework", "framework", "app", "bundle",
        "lproj", "playground", "git"
    ]

    private static let maxDepth = 6
    private static let maxDirectoriesVisited = 20_000

    // MARK: - Scanning

    /// The cache folders inside one project, each with its size on disk.
    /// - Parameter otherRoots: Other projects' folders. They are scanned on their own, so the walk stops at them.
    static func caches(inProjectAt projectPath: String, skipping otherRoots: Set<String> = []) -> [CacheItem] {
        var found: [(item: CacheItem, needsGitIgnore: Bool)] = []
        let fileManager = FileManager.default
        let rootPath = projectPath.hasSuffix("/") ? String(projectPath.dropLast()) : projectPath

        // Paths are built from the project path rather than read back from the file system,
        // so they keep the spelling the rest of the app knows the project by.
        var queue: [(relativePath: String, depth: Int)] = [("", 0)]
        var visited = 0

        while !queue.isEmpty, visited < maxDirectoriesVisited, !Task.isCancelled {
            let (relativeDirectory, depth) = queue.removeFirst()
            visited += 1

            let directory = URL(fileURLWithPath: rootPath + "/" + relativeDirectory, isDirectory: true)
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            ) else { continue }

            let names = Set(entries.map(\.lastPathComponent))
            let extensions = Set(entries.map { $0.pathExtension.lowercased() })

            for entry in entries {
                guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      values.isDirectory == true, values.isSymbolicLink != true else { continue }
                let name = entry.lastPathComponent
                let relativePath = relativeDirectory.isEmpty ? name : relativeDirectory + "/" + name

                if let rule = rulesByName[name]?.first(where: { matches($0, folder: entry, siblingNames: names, siblingExtensions: extensions) }) {
                    let target = rule.subpath.map { relativePath + "/" + $0 } ?? relativePath
                    found.append((CacheItem(path: rootPath + "/" + target, displayName: target, kind: rule.kind), rule.needsGitIgnore))
                    continue
                }

                guard depth < maxDepth,
                      !name.hasPrefix("."),
                      !opaqueExtensions.contains(entry.pathExtension.lowercased()),
                      !otherRoots.contains(rootPath + "/" + relativePath) else { continue }
                queue.append((relativePath, depth + 1))
            }
        }

        let ambiguous = found.filter(\.needsGitIgnore).map(\.item.displayName)
        let ignored = ambiguous.isEmpty ? [] : gitIgnored(ambiguous, in: projectPath)

        return found.compactMap { candidate in
            if candidate.needsGitIgnore, !ignored.contains(candidate.item.displayName) { return nil }
            var item = candidate.item
            item.size = directorySize(atPath: item.path)
            return item.size > 0 ? item : nil
        }
    }

    private static func matches(_ rule: Rule, folder: URL, siblingNames: Set<String>, siblingExtensions: Set<String>) -> Bool {
        let fileManager = FileManager.default

        if !rule.siblings.isEmpty {
            let hasSibling = rule.siblings.contains { sibling in
                sibling.hasPrefix("*.") ? siblingExtensions.contains(String(sibling.dropFirst(2))) : siblingNames.contains(sibling)
            }
            guard hasSibling else { return false }
        }
        if let marker = rule.contains,
           !fileManager.fileExists(atPath: folder.appendingPathComponent(marker).path) {
            return false
        }
        if let subpath = rule.subpath {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.appendingPathComponent(subpath).path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { return false }
        }
        return true
    }

    /// The given project-relative paths that git ignores. Empty when the project is not a repository.
    private static func gitIgnored(_ relativePaths: [String], in projectPath: String) -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        // NUL-separated on both ends, so unusual folder names survive the round trip.
        process.arguments = ["-C", projectPath, "check-ignore", "-z", "--stdin"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }
        let request = Data(relativePaths.map { $0 + "\0" }.joined().utf8)
        try? input.fileHandleForWriting.write(contentsOf: request)
        try? input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else { return [] }
        return Set(text.split(separator: "\0").map(String.init))
    }

    // MARK: - Xcode DerivedData

    /// Xcode's per-workspace build folders, as (the workspace they were built from, the folder).
    static func derivedDataFolders() -> [(workspacePath: String, folder: URL)] {
        let fileManager = FileManager.default
        var roots = [fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)]
        if let custom = UserDefaults(suiteName: "com.apple.dt.Xcode")?.string(forKey: "IDECustomDerivedDataLocation"),
           custom.hasPrefix("/") {
            roots.append(URL(fileURLWithPath: custom, isDirectory: true))
        }

        var result: [(String, URL)] = []
        for root in roots {
            guard let folders = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for folder in folders {
                let infoURL = folder.appendingPathComponent("info.plist")
                guard let data = try? Data(contentsOf: infoURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let workspace = plist["WorkspacePath"] as? String else { continue }
                result.append((workspace, folder))
            }
        }
        return result
    }

    /// DerivedData folders grouped by the project they belong to: the deepest project folder holding the workspace.
    static func derivedData(forProjectsAt projectPaths: [String]) -> [String: [CacheItem]] {
        let byLength = projectPaths.sorted { $0.count > $1.count }
        var result: [String: [CacheItem]] = [:]

        for (workspace, folder) in derivedDataFolders() {
            guard let owner = byLength.first(where: { workspace == $0 || workspace.hasPrefix($0 + "/") }) else { continue }
            result[owner, default: []].append(
                CacheItem(path: folder.path, displayName: "DerivedData/\(folder.lastPathComponent)", kind: .derivedData)
            )
        }
        return result
    }

    // MARK: - Size

    /// Space the folder takes on disk, in bytes.
    static func directorySize(atPath path: String) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path, isDirectory: true),
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        var count = 0
        for case let url as URL in enumerator {
            count += 1
            if count.isMultiple(of: 2_000), Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: - Removal

    enum RemovalError: Error {
        case notACacheFolder
    }

    /// Removes one cache folder. Only real directories nested well below the volume root are accepted.
    static func remove(_ path: String, toTrash: Bool) throws {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard path.hasPrefix("/"), url.pathComponents.count > 3,
              values.isDirectory == true, values.isSymbolicLink != true else {
            throw RemovalError.notACacheFolder
        }

        if toTrash {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        } else {
            try fileManager.removeItem(at: url)
        }
    }
}
