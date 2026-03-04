import Foundation

actor ProjectScanner {
    private let fileManager = FileManager.default
    
    // User-defined excluded paths
    private var excludedPaths: [String] = []

    private func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    private let skipDirectories: Set<String> = [
        "node_modules", ".git", ".svn", ".hg", "bin", "obj", "build",
        "dist", ".next", ".nuxt", "__pycache__", ".venv", "venv",
        ".idea", ".vs", ".vscode", "pods", "deriveddata", ".build",
        "target", "vendor", ".cache", ".output", "coverage",
        "library", "system", ".trash", "applications", "opt", "usr",
        "debug", "release", "packages", "carthage", "frameworks",
        ".xcodeproj", ".xcworkspace",
        "flutter",
        // macOS system directories
        "var", "private", "tmp", "etc", "sbin", "dev", "cores",
        "net", "home", "private"
    ]
    
    // MARK: - Configuration
    
    func setExcludedPaths(_ paths: [String]) {
        self.excludedPaths = paths.map { normalizePath($0) }
    }
    
    private func isPathExcluded(_ path: String) -> Bool {
        let normalizedPath = normalizePath(path)
        for excludedPath in excludedPaths {
            if normalizedPath == excludedPath || normalizedPath.hasPrefix(excludedPath + "/") {
                return true
            }
        }
        return false
    }

    // MARK: - Project Type Detection

    private let extensionMarkers: [String: String] = [
        "csproj": ".NET",
        "fsproj": "F#",
        "vbproj": "VB.NET",
        "sln": ".NET Solution",
        "slnx": ".NET Solution",
        "xcodeproj": "Xcode",
        "xcworkspace": "Xcode Workspace"
    ]

    private let fileMarkers: [String: String] = [
        "package.json": "Node.js",
        "go.mod": "Go",
        "Cargo.toml": "Rust",
        "pom.xml": "Java/Maven",
        "build.gradle": "Java/Gradle",
        "build.gradle.kts": "Java/Gradle",
        "composer.json": "PHP",
        "Gemfile": "Ruby",
        "requirements.txt": "Python",
        "pyproject.toml": "Python",
        "Pipfile": "Python",
        "setup.py": "Python",
        "main.py": "Python",
        "app.py": "Python",
        "pubspec.yaml": "Flutter",
        "Podfile": "iOS",
        "Package.swift": "Swift",
        "angular.json": "Angular",
        "next.config.js": "Next.js",
        "next.config.mjs": "Next.js",
        "next.config.ts": "Next.js",
        "vue.config.js": "Vue",
        "vite.config.js": "Vite",
        "vite.config.ts": "Vite",
        "Dockerfile": "Docker",
        "docker-compose.yml": "Docker",
        "docker-compose.yaml": "Docker"
    ]

    private let fileTags: [String: [String]] = [
        "package.json": ["JavaScript", "Node.js"],
        "tsconfig.json": ["TypeScript"],
        "next.config.js": ["React", "Next.js"],
        "next.config.mjs": ["React", "Next.js"],
        "next.config.ts": ["React", "Next.js"],
        "angular.json": ["Angular", "TypeScript"],
        "vue.config.js": ["Vue"],
        "vite.config.js": ["Vite"],
        "vite.config.ts": ["Vite", "TypeScript"],
        "go.mod": ["Go"],
        "Cargo.toml": ["Rust"],
        "pom.xml": ["Java", "Maven"],
        "build.gradle": ["Java", "Gradle"],
        "build.gradle.kts": ["Java", "Gradle"],
        "composer.json": ["PHP"],
        "Gemfile": ["Ruby"],
        "requirements.txt": ["Python"],
        "pyproject.toml": ["Python"],
        "Pipfile": ["Python"],
        "setup.py": ["Python"],
        "pubspec.yaml": ["Flutter", "Dart"],
        "Podfile": ["iOS", "Swift"],
        "Package.swift": ["Swift"],
        "Dockerfile": ["Docker"],
        "docker-compose.yml": ["Docker"],
        "docker-compose.yaml": ["Docker"]
    ]

    private let extensionTags: [String: [String]] = [
        "xcodeproj": ["Swift", "iOS", "Xcode"],
        "xcworkspace": ["Swift", "iOS", "Xcode"],
        "csproj": ["C#", ".NET Core"],
        "fsproj": ["F#", ".NET Core"],
        "vbproj": ["VB.NET", ".NET Core"],
        "sln": ["C#", ".NET Core"],
        "slnx": ["C#", ".NET Core"]
    ]

    // MARK: - Scanning

    func scanAllDrives(progress: @escaping @Sendable (ScanProgress) -> Void) async -> [ProjectInfo] {
        var projects: [ProjectInfo] = []
        var scanProgress = ScanProgress()
        scanProgress.isScanning = true

        let volumes = getVolumes()

        for volume in volumes {
            progress(scanProgress)

            let found = await scanDirectory(
                at: volume,
                progress: &scanProgress,
                progressCallback: progress
            )
            projects.append(contentsOf: found)
        }

        scanProgress.progressPercentage = 100.0
        scanProgress.isScanning = false
        progress(scanProgress)

        return projects
    }

    private func getVolumes() -> [String] {
        var volumes: [String] = []
        let volumesPath = "/Volumes"

        if let contents = try? fileManager.contentsOfDirectory(atPath: volumesPath) {
            for item in contents {
                let fullPath = "\(volumesPath)/\(item)"
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    volumes.append(fullPath)
                }
            }
        }

        let home = fileManager.homeDirectoryForCurrentUser.path
        if !volumes.contains(where: { home.hasPrefix($0) }) {
            volumes.insert(home, at: 0)
        }

        return volumes
    }

    private func isSystemPath(_ path: String) -> Bool {
        let systemPathSuffixes = [
            "/var/folders", "/private/var", "/private/tmp",
            "/private/etc", "/System", "/Library/Caches",
            "/var/root", "/var/db"
        ]
        let normalizedPath = normalizePath(path)
        return systemPathSuffixes.contains { normalizedPath.hasSuffix($0) || normalizedPath.contains($0 + "/") }
    }

    private func scanDirectory(
        at path: String,
        progress: inout ScanProgress,
        progressCallback: @escaping @Sendable (ScanProgress) -> Void,
        depth: Int = 0
    ) async -> [ProjectInfo] {
        guard depth < 10 else { return [] }
        
        // Check if path is excluded or is a system path
        if isPathExcluded(path) || isSystemPath(path) {
            return []
        }

        var projects: [ProjectInfo] = []

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        progress.directoriesScanned += 1
        progress.currentPath = path

        if progress.directoriesScanned % 50 == 0 {
            let totalEstimate = max(Double(progress.directoriesScanned), 1000.0)
            progress.progressPercentage = min(
                (Double(progress.directoriesScanned) / totalEstimate) * 100.0,
                95.0
            )
            progressCallback(progress)
        }

        if let project = detectProject(at: path, files: contents) {
            projects.append(project)
            progress.projectsFound += 1
            progressCallback(progress)
            return projects
        }

        for item in contents {
            guard !skipDirectories.contains(item.lowercased()), !item.hasPrefix(".") else { continue }

            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false

            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            let found = await scanDirectory(
                at: fullPath,
                progress: &progress,
                progressCallback: progressCallback,
                depth: depth + 1
            )
            projects.append(contentsOf: found)
        }

        return projects
    }

    // MARK: - Project Detection

    private func detectProject(at path: String, files: [String]) -> ProjectInfo? {
        var projectType: String?
        var tags: Set<String> = []

        for file in files {
            let ext = (file as NSString).pathExtension
            if let type = extensionMarkers[ext] {
                projectType = type
                if let extTags = extensionTags[ext] {
                    tags.formUnion(extTags)
                }
            }

            if let type = fileMarkers[file] {
                if projectType == nil || isPriorityType(type, over: projectType!) {
                    projectType = type
                }
            }

            if let fileTags = self.fileTags[file] {
                tags.formUnion(fileTags)
            }
        }

        guard let type = projectType else { return nil }

        let name = (path as NSString).lastPathComponent
        let category = detectCategory(type: type, tags: Array(tags))
        let gitBranch = detectGitBranch(at: path)
        let lastModified = getLastModified(at: path)
        let iconColor = generateIconColor(type: type)

        return ProjectInfo(
            name: name,
            path: path,
            projectType: type,
            category: category,
            tags: Array(tags).sorted(),
            lastModified: lastModified,
            isActive: isProjectActive(at: path),
            gitBranch: gitBranch,
            iconColor: iconColor
        )
    }

    private func isPriorityType(_ newType: String, over currentType: String) -> Bool {
        let priority = ["Next.js", "Angular", "Vue", "Vite", "React", "Flutter", "Swift"]
        let newPriority = priority.firstIndex(of: newType) ?? Int.max
        let currentPriority = priority.firstIndex(of: currentType) ?? Int.max
        return newPriority < currentPriority
    }

    // MARK: - Category Detection

    private func detectCategory(type: String, tags: [String]) -> ProjectCategory {
        let webTypes: Set<String> = [
            "React", "Next.js", "Vue", "Angular", "Vite", "Node.js", "PHP", "Ruby", "Go"
        ]
        let desktopTypes: Set<String> = [".NET", ".NET Solution", "F#", "VB.NET"]
        let mobileTypes: Set<String> = ["iOS", "Flutter", "Xcode", "Xcode Workspace"]
        let cloudTypes: Set<String> = ["Docker"]

        if mobileTypes.contains(type) { return .mobile }
        if cloudTypes.contains(type) { return .cloud }
        if webTypes.contains(type) { return .web }
        if desktopTypes.contains(type) { return .desktop }

        let allTags = Set(tags + [type])
        if !allTags.isDisjoint(with: webTypes) { return .web }
        if !allTags.isDisjoint(with: mobileTypes) { return .mobile }

        return .other
    }

    // MARK: - Git Branch Detection

    private func detectGitBranch(at path: String) -> String? {
        let headPath = (path as NSString).appendingPathComponent(".git/HEAD")
        guard let content = try? String(contentsOfFile: headPath, encoding: .utf8) else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("ref: refs/heads/") {
            return String(trimmed.dropFirst("ref: refs/heads/".count))
        }
        return String(trimmed.prefix(7))
    }

    // MARK: - Helpers

    private func getLastModified(at path: String) -> Date {
        let attrs = try? fileManager.attributesOfItem(atPath: path)
        return attrs?[.modificationDate] as? Date ?? Date()
    }

    private func isProjectActive(at path: String) -> Bool {
        let lockFiles = ["package-lock.json", "yarn.lock", "pnpm-lock.yaml", ".git/index.lock"]
        for lock in lockFiles {
            let lockPath = (path as NSString).appendingPathComponent(lock)
            if fileManager.fileExists(atPath: lockPath) {
                if let attrs = try? fileManager.attributesOfItem(atPath: lockPath),
                   let modified = attrs[.modificationDate] as? Date {
                    return Date().timeIntervalSince(modified) < 86400
                }
            }
        }

        if let attrs = try? fileManager.attributesOfItem(atPath: path),
           let modified = attrs[.modificationDate] as? Date {
            return Date().timeIntervalSince(modified) < 86400 * 7
        }
        return false
    }

    private func generateIconColor(type: String) -> String {
        let typeColors: [String: String] = [
            "Node.js": "68A063",
            "React": "61DAFB",
            "Next.js": "000000",
            "Vue": "42B883",
            "Angular": "DD0031",
            "Vite": "646CFF",
            ".NET": "512BD4",
            ".NET Solution": "512BD4",
            "F#": "378BBA",
            "VB.NET": "00539C",
            "Go": "00ADD8",
            "Rust": "DEA584",
            "Java/Maven": "F89820",
            "Java/Gradle": "02303A",
            "PHP": "777BB4",
            "Ruby": "CC342D",
            "Python": "3776AB",
            "Flutter": "02569B",
            "iOS": "147EFB",
            "Swift": "FA7343",
            "Docker": "2496ED",
            "Xcode": "147EFB",
            "Xcode Workspace": "147EFB"
        ]
        return typeColors[type] ?? "6B7280"
    }
}
