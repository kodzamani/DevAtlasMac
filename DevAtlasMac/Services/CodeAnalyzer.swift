import Foundation

// MARK: - Analyzer

enum CodeAnalyzer {

    // MARK: - Public API

    static func analyze(for project: ProjectInfo) async -> CodeAnalysisResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = analyzeSync(projectPath: project.path)
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Skip Directories

    private static let skipDirectories: Set<String> = [
        // Version control
        ".git", ".svn", ".hg",
        // Node / JS
        "node_modules", "bower_components", ".next", ".nuxt", ".angular",
        ".svelte-kit", ".parcel-cache", ".turbo", ".vercel", ".netlify", ".expo",
        // .NET / C#
        "bin", "obj", "debug", "release", "x64", "x86", "testresults", "packages",
        // Build outputs
        "build", "dist", "out", ".output", ".build", "cmake-build-debug",
        "cmake-build-release",
        // Java / Kotlin
        "target", ".gradle", ".m2",
        // Python
        "__pycache__", ".venv", "venv", "env", ".tox", "__pypackages__",
        // Dart / Flutter
        ".dart_tool", ".pub-cache",
        // iOS / macOS
        "pods", "deriveddata", "carthage", "frameworks",
        // IDE
        ".idea", ".vs", ".vscode", ".xcodeproj", ".xcworkspace",
        // Misc
        "vendor", ".cache", "coverage", ".terraform", ".serverless", ".aws-sam", "usr",
    ]

    // MARK: - Skip Files (lock / generated)

    private static let skipFiles: Set<String> = [
        "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
        "composer.lock", "gemfile.lock", "podfile.lock",
        "package.resolved", "cargo.lock", "go.sum",
        "pubspec.lock", "packages.lock.json",
        ".ds_store", "thumbs.db",
    ]

    // MARK: - Skip Suffixes (minified / generated)

    private static let skipSuffixes: [String] = [
        ".min.js", ".min.css", ".bundle.js", ".bundle.css",
        ".chunk.js", ".chunk.css", ".g.dart", ".designer.cs",
        ".pb.go", ".pb.cc", ".pb.h", ".swagger.json",
        ".generated.swift", ".g.cs"
    ]

    // MARK: - Supported Extensions

    private static let supportedExtensions: Set<String> = [
        // Swift / Apple
        "swift", "m", "mm", "h",
        // C / C++
        "c", "cpp", "cc", "cxx", "hpp",
        // .NET
        "cs", "fs", "vb", "cshtml", "razor",
        // JVM
        "java", "kt", "kts", "scala", "groovy",
        // Go / Rust / Zig
        "go", "rs", "zig",
        // Python / Ruby / Perl
        "py", "rb", "pl",
        // JS / TS / Web
        "js", "jsx", "ts", "tsx", "vue", "svelte", "astro",
        // PHP
        "php",
        // Dart
        "dart",
        // Markup / Style
        "html", "css", "scss", "less", "sass",
        // Data / Config
        "xml", "yaml", "yml", "toml",
        // Script / Shell
        "sh", "bash", "ps1", "bat", "cmd",
        // Other
        "sql", "graphql", "gql", "proto", "r", "lua",
        "ex", "exs", "nim", "md", "mdx", "tf",
        "dockerfile",
    ]

    // MARK: - Language Mapping

    private static let extensionToLanguage: [String: String] = [
        "swift": "Swift", "m": "Objective-C", "mm": "Objective-C++", "h": "C/C++ Header",
        "c": "C", "cpp": "C++", "cc": "C++", "cxx": "C++", "hpp": "C++ Header",
        "cs": "C#", "fs": "F#", "vb": "VB.NET", "cshtml": "Razor", "razor": "Razor",
        "java": "Java", "kt": "Kotlin", "kts": "Kotlin", "scala": "Scala", "groovy": "Groovy",
        "go": "Go", "rs": "Rust", "zig": "Zig",
        "py": "Python", "rb": "Ruby", "pl": "Perl",
        "js": "JavaScript", "jsx": "JavaScript", "ts": "TypeScript", "tsx": "TypeScript",
        "vue": "Vue", "svelte": "Svelte", "astro": "Astro",
        "php": "PHP", "dart": "Dart",
        "html": "HTML", "css": "CSS", "scss": "SCSS", "less": "Less", "sass": "Sass",
        "xml": "XML", "yaml": "YAML", "yml": "YAML", "toml": "TOML",
        "sh": "Shell", "bash": "Shell", "ps1": "PowerShell", "bat": "Batch", "cmd": "Batch",
        "sql": "SQL", "graphql": "GraphQL", "gql": "GraphQL", "proto": "Protobuf",
        "r": "R", "lua": "Lua", "ex": "Elixir", "exs": "Elixir",
        "nim": "Nim", "md": "Markdown", "mdx": "MDX", "tf": "Terraform",
        "dockerfile": "Dockerfile",
    ]

    private static let languageColors: [String: String] = [
        "Swift": "FA7343", "Objective-C": "438EFF", "Objective-C++": "6866FB",
        "C": "555555", "C++": "F34B7D", "C++ Header": "F34B7D", "C/C++ Header": "555555",
        "C#": "178600", "F#": "B845FC", "VB.NET": "945DB7", "Razor": "512BD4",
        "Java": "B07219", "Kotlin": "A97BFF", "Scala": "C22D40", "Groovy": "4298B8",
        "Go": "00ADD8", "Rust": "DEA584", "Zig": "EC915C",
        "Python": "3572A5", "Ruby": "701516", "Perl": "0298C3",
        "JavaScript": "F1E05A", "TypeScript": "3178C6",
        "Vue": "41B883", "Svelte": "FF3E00", "Astro": "FF5A03",
        "PHP": "4F5D95", "Dart": "00B4AB",
        "HTML": "E34C26", "CSS": "563D7C", "SCSS": "C6538C", "Less": "1D365D", "Sass": "A53B70",
        "XML": "0060AC", "YAML": "CB171E", "TOML": "9C4221",
        "Shell": "89E051", "PowerShell": "012456",
        "SQL": "E38C00", "GraphQL": "E10098", "Protobuf": "6B7280",
        "R": "198CE7", "Lua": "000080", "Elixir": "6E4A7E",
        "Markdown": "083FA1", "MDX": "FCB32C", "Terraform": "5C4EE5",
        "Dockerfile": "384D54",
    ]

    // MARK: - Sync Analysis

    private static func analyzeSync(projectPath: String) -> CodeAnalysisResult {
        let fm = FileManager.default
        let projectURL = URL(fileURLWithPath: projectPath)
        var fileInfos: [FileLineInfo] = []
        var languageLines: [String: Int] = [:]

        guard let enumerator = fm.enumerator(
            at: projectURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return CodeAnalysisResult(files: [], totalLines: 0, totalFiles: 0, languageBreakdown: [])
        }

        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent

            let lowerName = name.lowercased()

            // Skip known directories
            if skipDirectories.contains(lowerName) {
                enumerator.skipDescendants()
                continue
            }

            // Skip lock / generated files
            if skipFiles.contains(lowerName) {
                continue
            }

            // Skip minified or clearly generated suffixes
            if skipSuffixes.contains(where: { lowerName.hasSuffix($0) }) {
                continue
            }

            // Also skip hidden directories starting with dot (beyond .skipsHiddenFiles)
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()

            // Handle Dockerfile specifically (no extension)
            let effectiveExt: String
            if ext.isEmpty {
                if name.lowercased() == "dockerfile" {
                    effectiveExt = "dockerfile"
                } else {
                    continue
                }
            } else {
                effectiveExt = ext
            }

            guard supportedExtensions.contains(effectiveExt) else { continue }

            // Count lines
            guard let lineCount = countLines(at: fileURL) else { continue }

            let relativePath = fileURL.path.replacingOccurrences(
                of: projectPath + "/",
                with: ""
            )

            let info = FileLineInfo(
                relativePath: relativePath,
                fileExtension: effectiveExt.isEmpty ? "–" : ".\(effectiveExt)",
                lineCount: lineCount
            )
            fileInfos.append(info)

            // Accumulate language stats
            let language = extensionToLanguage[effectiveExt] ?? effectiveExt.uppercased()
            languageLines[language, default: 0] += lineCount
        }

        // Sort descending by line count
        fileInfos.sort { $0.lineCount > $1.lineCount }

        let totalLines = fileInfos.reduce(0) { $0 + $1.lineCount }
        let totalFiles = fileInfos.count

        // Build language breakdown
        let breakdown = languageLines
            .sorted { $0.value > $1.value }
            .map { lang, lines in
                LanguageBreakdown(
                    language: lang,
                    percentage: totalLines > 0 ? Double(lines) / Double(totalLines) * 100 : 0,
                    color: languageColors[lang] ?? "6B7280"
                )
            }

        return CodeAnalysisResult(
            files: fileInfos,
            totalLines: totalLines,
            totalFiles: totalFiles,
            languageBreakdown: breakdown
        )
    }

    // MARK: - Line Counter

    private static func countLines(at url: URL) -> Int? {
        guard let data = try? Data(contentsOf: url),
              data.count < 5_000_000 else { return nil } // Skip files > 5MB

        guard let content = String(data: data, encoding: .utf8) else { return nil }

        // Count newlines + 1 for last line (if non-empty)
        if content.isEmpty { return 0 }
        return content.components(separatedBy: "\n").count
    }
}
