import Foundation

// MARK: - JavaScript/TypeScript Analyzer

class JavaScriptAnalyzer: LanguageAnalyzer {
    let supportedExtensions = ["js", "jsx", "ts", "tsx", "mjs", "cjs", "mts", "cts"]
    let languageName = "JavaScript"

    private let referenceExtensions: Set<String> = [
        "js", "jsx", "ts", "tsx", "mjs", "cjs", "mts", "cts",
        "vue", "svelte", "astro", "mdx", "md", "html"
    ]

    private let ignoredDirectories = [
        "node_modules/",
        ".next/",
        ".nuxt/",
        "dist/",
        "build/",
        "coverage/",
        ".turbo/",
        ".cache/",
        "storybook-static/"
    ]

    private let ignoredSymbolNames = Set(["undefined", "NaN", "arguments"])

    func analyze(projectPath: String) throws -> [UnusedCodeResult] {
        let sourceFiles = try collectSourceFiles(at: projectPath)
        guard !sourceFiles.isEmpty else { return [] }

        let searchableProjectContent = try collectSearchableProjectContent(at: projectPath)
        let compilerResults = (try? runTypeScriptCompilerAnalysis(at: projectPath, sourceFiles: sourceFiles)) ?? []
        let regexResults = try javascriptRegexAnalysis(
            sourceFiles: sourceFiles,
            searchableProjectContent: searchableProjectContent
        )

        return deduplicate(results: compilerResults + regexResults)
    }

    private func javascriptRegexAnalysis(
        sourceFiles: [SourceFile],
        searchableProjectContent: String
    ) throws -> [UnusedCodeResult] {
        let arrowFunctionRegex = try NSRegularExpression(
            pattern: #"(?:export\s+default\s+|export\s+)?(?:const|let|var)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(?:async\s+)?(?:\([^)]*\)|[a-zA-Z_$][a-zA-Z0-9_$]*)\s*=>"#,
            options: []
        )
        let functionRegex = try NSRegularExpression(
            pattern: #"(?:export\s+default\s+|export\s+)?(?:async\s+)?function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\("#,
            options: []
        )
        let classRegex = try NSRegularExpression(
            pattern: #"(?:export\s+default\s+|export\s+)?(?:abstract\s+)?class\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\b"#,
            options: []
        )
        let interfaceRegex = try NSRegularExpression(
            pattern: #"(?:export\s+)?interface\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\b"#,
            options: []
        )
        let typeAliasRegex = try NSRegularExpression(
            pattern: #"(?:export\s+)?type\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\b"#,
            options: []
        )
        let enumRegex = try NSRegularExpression(
            pattern: #"(?:export\s+)?(?:const\s+)?enum\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\b"#,
            options: []
        )
        let variableRegex = try NSRegularExpression(
            pattern: #"(?:export\s+)?(?:const|let|var)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*="#,
            options: []
        )

        var results: [UnusedCodeResult] = []

        for sourceFile in sourceFiles where !sourceFile.isDeclarationFile {
            let exportedNames = collectExportedNames(from: sourceFile.content)
            var declarations: [Declaration] = []

            for (index, line) in sourceFile.lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard shouldAnalyze(line: trimmed) else { continue }

                let lineNumber = index + 1

                if let name = firstCapture(in: line, using: arrowFunctionRegex),
                   shouldTrackDeclaration(named: name) {
                    declarations.append(
                        Declaration(
                            kind: "function",
                            name: name,
                            location: "\(sourceFile.relativePath):\(lineNumber)",
                            hints: [hint(for: "function", exported: isExported(name: name, line: line, exportedNames: exportedNames))],
                            searchScope: isExported(name: name, line: line, exportedNames: exportedNames) ? .project : .file
                        )
                    )
                    continue
                }

                if let name = firstCapture(in: line, using: functionRegex),
                   shouldTrackDeclaration(named: name) {
                    declarations.append(
                        Declaration(
                            kind: "function",
                            name: name,
                            location: "\(sourceFile.relativePath):\(lineNumber)",
                            hints: [hint(for: "function", exported: isExported(name: name, line: line, exportedNames: exportedNames))],
                            searchScope: isExported(name: name, line: line, exportedNames: exportedNames) ? .project : .file
                        )
                    )
                    continue
                }

                if let name = firstCapture(in: line, using: classRegex),
                   shouldTrackDeclaration(named: name) {
                    declarations.append(
                        Declaration(
                            kind: "class",
                            name: name,
                            location: "\(sourceFile.relativePath):\(lineNumber)",
                            hints: [hint(for: "class", exported: isExported(name: name, line: line, exportedNames: exportedNames))],
                            searchScope: isExported(name: name, line: line, exportedNames: exportedNames) ? .project : .file
                        )
                    )
                    continue
                }

                if let name = firstCapture(in: line, using: interfaceRegex),
                   shouldTrackDeclaration(named: name) {
                    declarations.append(
                        Declaration(
                            kind: "interface",
                            name: name,
                            location: "\(sourceFile.relativePath):\(lineNumber)",
                            hints: [hint(for: "interface", exported: isExported(name: name, line: line, exportedNames: exportedNames))],
                            searchScope: isExported(name: name, line: line, exportedNames: exportedNames) ? .project : .file
                        )
                    )
                    continue
                }

                if let name = firstCapture(in: line, using: typeAliasRegex),
                   shouldTrackDeclaration(named: name) {
                    declarations.append(
                        Declaration(
                            kind: "typealias",
                            name: name,
                            location: "\(sourceFile.relativePath):\(lineNumber)",
                            hints: [hint(for: "typealias", exported: isExported(name: name, line: line, exportedNames: exportedNames))],
                            searchScope: isExported(name: name, line: line, exportedNames: exportedNames) ? .project : .file
                        )
                    )
                    continue
                }

                if let name = firstCapture(in: line, using: enumRegex),
                   shouldTrackDeclaration(named: name) {
                    declarations.append(
                        Declaration(
                            kind: "enum",
                            name: name,
                            location: "\(sourceFile.relativePath):\(lineNumber)",
                            hints: [hint(for: "enum", exported: isExported(name: name, line: line, exportedNames: exportedNames))],
                            searchScope: isExported(name: name, line: line, exportedNames: exportedNames) ? .project : .file
                        )
                    )
                    continue
                }

                if let name = firstCapture(in: line, using: variableRegex),
                   shouldTrackDeclaration(named: name),
                   !looksLikeFunctionOrClassAssignment(line) {
                    declarations.append(
                        Declaration(
                            kind: "variable",
                            name: name,
                            location: "\(sourceFile.relativePath):\(lineNumber)",
                            hints: [hint(for: "variable", exported: isExported(name: name, line: line, exportedNames: exportedNames))],
                            searchScope: isExported(name: name, line: line, exportedNames: exportedNames) ? .project : .file
                        )
                    )
                }
            }

            for declaration in declarations {
                let searchableContent = declaration.searchScope == .project ? searchableProjectContent : sourceFile.searchableContent
                let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: declaration.name))\b"#
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

                let matches = regex.matches(
                    in: searchableContent,
                    range: NSRange(location: 0, length: (searchableContent as NSString).length)
                )

                if matches.count <= 1 {
                    results.append(
                        UnusedCodeResult(
                            kind: declaration.kind,
                            name: declaration.name,
                            location: declaration.location,
                            hints: declaration.hints
                        )
                    )
                }
            }
        }

        return deduplicate(results: results)
    }

    private func collectSourceFiles(at projectPath: String) throws -> [SourceFile] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: projectPath) else { return [] }

        var sourceFiles: [SourceFile] = []

        while let relativePath = enumerator.nextObject() as? String {
            let pathExtension = (relativePath as NSString).pathExtension.lowercased()
            guard supportedExtensions.contains(pathExtension), !shouldIgnore(relativePath: relativePath) else {
                continue
            }

            let absolutePath = (projectPath as NSString).appendingPathComponent(relativePath)
            guard let content = try? String(contentsOfFile: absolutePath, encoding: .utf8) else { continue }

            let isDeclarationFile = relativePath.lowercased().hasSuffix(".d.ts")
            sourceFiles.append(
                SourceFile(
                    path: standardizedPath(absolutePath),
                    relativePath: relativePath,
                    content: content,
                    searchableContent: isDeclarationFile ? "" : stripComments(from: content),
                    lines: content.components(separatedBy: .newlines),
                    isDeclarationFile: isDeclarationFile
                )
            )
        }

        return sourceFiles
    }

    private func collectSearchableProjectContent(at projectPath: String) throws -> String {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: projectPath) else { return "" }

        var contents: [String] = []

        while let relativePath = enumerator.nextObject() as? String {
            let pathExtension = (relativePath as NSString).pathExtension.lowercased()
            guard referenceExtensions.contains(pathExtension), !shouldIgnore(relativePath: relativePath) else {
                continue
            }
            guard !relativePath.lowercased().hasSuffix(".d.ts") else { continue }

            let absolutePath = (projectPath as NSString).appendingPathComponent(relativePath)
            guard let content = try? String(contentsOfFile: absolutePath, encoding: .utf8) else { continue }

            contents.append(stripComments(from: content))
        }

        return contents.joined(separator: "\n")
    }

    private func runTypeScriptCompilerAnalysis(at projectPath: String, sourceFiles: [SourceFile]) throws -> [UnusedCodeResult] {
        guard let compiler = resolveTypeScriptCompiler(at: projectPath) else {
            return []
        }

        var arguments = ["--pretty", "false", "--noEmit", "--noUnusedLocals", "--noUnusedParameters"]
        var temporaryConfigURL: URL?

        if let configName = existingTypeScriptConfigName(at: projectPath) {
            arguments.append(contentsOf: ["--project", configName])
        } else {
            let tempConfigURL = try createTemporaryTypeScriptConfig(for: sourceFiles)
            temporaryConfigURL = tempConfigURL
            arguments.append(contentsOf: ["--project", tempConfigURL.path])
        }

        defer {
            if let temporaryConfigURL {
                try? FileManager.default.removeItem(at: temporaryConfigURL)
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: compiler.path)
        process.arguments = compiler.arguments + arguments
        process.currentDirectoryPath = projectPath

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return []
        }

        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let output = [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !output.isEmpty else { return [] }

        return parseTypeScriptDiagnostics(output, projectPath: projectPath, sourceFiles: sourceFiles)
    }

    private func resolveTypeScriptCompiler(at projectPath: String) -> Executable? {
        let candidates = [
            (projectPath as NSString).appendingPathComponent("node_modules/.bin/tsc"),
            (projectPath as NSString).appendingPathComponent("node_modules/typescript/bin/tsc"),
            "/opt/homebrew/bin/tsc",
            "/usr/local/bin/tsc"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return Executable(path: candidate, arguments: [])
        }

        guard let pathOnShell = resolveExecutableOnPath(named: "tsc") else {
            return nil
        }

        return Executable(path: pathOnShell, arguments: [])
    }

    private func resolveExecutableOnPath(named command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let output, !output.isEmpty else { return nil }
        return output
    }

    private func existingTypeScriptConfigName(at projectPath: String) -> String? {
        let fileManager = FileManager.default
        let candidates = ["tsconfig.json", "jsconfig.json"]

        for candidate in candidates {
            let configPath = (projectPath as NSString).appendingPathComponent(candidate)
            if fileManager.fileExists(atPath: configPath) {
                return candidate
            }
        }

        return nil
    }

    private func createTemporaryTypeScriptConfig(for sourceFiles: [SourceFile]) throws -> URL {
        let config: [String: Any] = [
            "compilerOptions": [
                "allowJs": true,
                "checkJs": true,
                "jsx": "react-jsx",
                "module": "esnext",
                "moduleResolution": "node",
                "target": "esnext",
                "skipLibCheck": true
            ],
            "files": sourceFiles.map(\.path)
        ]

        let configData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("devatlas-unused-\(UUID().uuidString)")
            .appendingPathExtension("json")

        try configData.write(to: url)
        return url
    }

    private func parseTypeScriptDiagnostics(_ output: String, projectPath: String, sourceFiles: [SourceFile]) -> [UnusedCodeResult] {
        let supportedCodes = Set(["6133", "6192", "6196"])
        let sourceFileLookup = Dictionary(uniqueKeysWithValues: sourceFiles.map { ($0.path, $0) })

        let formats = [
            try? NSRegularExpression(
                pattern: #"(.+)\((\d+),(\d+)\):\s*(?:error|warning)\s+TS(\d+):\s+(.+)"#,
                options: []
            ),
            try? NSRegularExpression(
                pattern: #"(.+):(\d+):(\d+)\s*-\s*(?:error|warning)\s+TS(\d+):\s+(.+)"#,
                options: []
            )
        ]

        var results: [UnusedCodeResult] = []

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            var diagnostic: TypeScriptDiagnostic?
            for regex in formats.compactMap({ $0 }) {
                if let parsed = parseDiagnosticLine(line, using: regex, projectPath: projectPath) {
                    diagnostic = parsed
                    break
                }
            }

            guard let diagnostic else { continue }
            guard supportedCodes.contains(diagnostic.code) else { continue }

            guard let sourceFile = sourceFileLookup[diagnostic.filePath], !sourceFile.isDeclarationFile else {
                continue
            }

            let sourceLine = sourceFile.lines[safe: diagnostic.line - 1] ?? ""
            let name = extractQuotedName(from: diagnostic.message) ?? guessDeclarationName(from: sourceLine)
            guard let name, shouldTrackDeclaration(named: name) else { continue }

            let kind = inferKind(named: name, from: sourceLine)
            let location = "\(sourceFile.relativePath):\(diagnostic.line)"

            results.append(
                UnusedCodeResult(
                    kind: kind,
                    name: name,
                    location: location,
                    hints: [compilerHint(for: kind)]
                )
            )
        }

        return deduplicate(results: results)
    }

    private func parseDiagnosticLine(_ line: String, using regex: NSRegularExpression, projectPath: String) -> TypeScriptDiagnostic? {
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)),
              match.numberOfRanges >= 6 else {
            return nil
        }

        let filePath = nsLine.substring(with: match.range(at: 1))
        let lineNumber = Int(nsLine.substring(with: match.range(at: 2))) ?? 0
        let columnNumber = Int(nsLine.substring(with: match.range(at: 3))) ?? 0
        let code = nsLine.substring(with: match.range(at: 4))
        let message = nsLine.substring(with: match.range(at: 5))

        guard lineNumber > 0, columnNumber > 0 else { return nil }

        let resolvedPath: String
        if filePath.hasPrefix("/") {
            resolvedPath = standardizedPath(filePath)
        } else {
            resolvedPath = standardizedPath((projectPath as NSString).appendingPathComponent(filePath))
        }

        return TypeScriptDiagnostic(
            filePath: resolvedPath,
            line: lineNumber,
            code: code,
            message: message
        )
    }

    private func collectExportedNames(from content: String) -> Set<String> {
        var exportedNames = Set<String>()
        let nsContent = content as NSString

        let listPatterns = [
            #"export\s+(?:type\s+)?\{([^}]*)\}"#,
            #"module\.exports\s*=\s*\{([^}]*)\}"#
        ]

        for pattern in listPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

            for match in matches where match.numberOfRanges > 1 {
                let rawList = nsContent.substring(with: match.range(at: 1))
                for name in parseExportList(rawList) {
                    exportedNames.insert(name)
                }
            }
        }

        let directPatterns = [
            #"export\s+default\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\b"#,
            #"exports\.[a-zA-Z_$][a-zA-Z0-9_$]*\s*=\s*([a-zA-Z_$][a-zA-Z0-9_$]*)"#,
            #"module\.exports\.[a-zA-Z_$][a-zA-Z0-9_$]*\s*=\s*([a-zA-Z_$][a-zA-Z0-9_$]*)"#,
            #"module\.exports\s*=\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\b"#
        ]

        for pattern in directPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

            for match in matches where match.numberOfRanges > 1 {
                exportedNames.insert(nsContent.substring(with: match.range(at: 1)))
            }
        }

        return exportedNames
    }

    private func parseExportList(_ rawList: String) -> [String] {
        rawList
            .split(separator: ",")
            .compactMap { rawItem in
                var item = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !item.isEmpty else { return nil }

                if item.hasPrefix("type ") {
                    item.removeFirst(5)
                    item = item.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                if item.contains(" as ") {
                    item = item.components(separatedBy: " as ").first ?? item
                }

                if let colonIndex = item.lastIndex(of: ":") {
                    let valueIndex = item.index(after: colonIndex)
                    item = String(item[valueIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                return shouldTrackDeclaration(named: item) ? item : nil
            }
    }

    private func shouldIgnore(relativePath: String) -> Bool {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")

        if normalized.lowercased().hasSuffix(".min.js") {
            return true
        }

        return ignoredDirectories.contains { normalized.contains($0) }
    }

    private func shouldAnalyze(line: String) -> Bool {
        guard !line.isEmpty else { return false }
        guard !line.hasPrefix("//"), !line.hasPrefix("/*"), !line.hasPrefix("*") else { return false }
        guard !line.hasPrefix("import ") else { return false }
        guard !line.hasPrefix("declare "), !line.hasPrefix("declare global"), !line.hasPrefix("declare module") else {
            return false
        }

        return true
    }

    private func shouldTrackDeclaration(named name: String) -> Bool {
        !name.hasPrefix("_") && !ignoredSymbolNames.contains(name)
    }

    private func looksLikeFunctionOrClassAssignment(_ line: String) -> Bool {
        line.contains("=>") || line.contains("= function") || line.contains("=class") || line.contains("= class")
    }

    private func isExported(name: String, line: String, exportedNames: Set<String>) -> Bool {
        line.contains("export ") || exportedNames.contains(name)
    }

    private func hint(for kind: String, exported: Bool) -> String {
        if exported {
            return "Exported \(kind) appears unreferenced across project"
        }
        return "\(kind.capitalized) appears unused"
    }

    private func compilerHint(for kind: String) -> String {
        switch kind {
        case "parameter":
            return "Compiler reported an unused parameter"
        case "import":
            return "Compiler reported an unused import"
        default:
            return "Compiler reported an unused \(kind)"
        }
    }

    private func inferKind(named name: String, from sourceLine: String) -> String {
        let trimmed = sourceLine.trimmingCharacters(in: .whitespaces)

        if trimmed.contains("import ") {
            return "import"
        }
        if isParameter(named: name, in: trimmed) {
            return "parameter"
        }
        if trimmed.contains("interface \(name)") {
            return "interface"
        }
        if trimmed.contains("type \(name)") {
            return "typealias"
        }
        if trimmed.contains("enum \(name)") {
            return "enum"
        }
        if trimmed.contains("class \(name)") {
            return "class"
        }
        if trimmed.contains("function \(name)") || trimmed.contains("=>") {
            return "function"
        }
        return "variable"
    }

    private func isParameter(named name: String, in sourceLine: String) -> Bool {
        guard sourceLine.contains("("), sourceLine.contains(")") else { return false }

        let patterns = [
            #"\(\s*\#(NSRegularExpression.escapedPattern(for: name))\s*[:,=\)]"#,
            #",\s*\#(NSRegularExpression.escapedPattern(for: name))\s*[:,=\)]"#
        ]

        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return false
            }

            let range = NSRange(location: 0, length: (sourceLine as NSString).length)
            return regex.firstMatch(in: sourceLine, range: range) != nil
        }
    }

    private func firstCapture(in line: String, using regex: NSRegularExpression) -> String? {
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)),
              match.numberOfRanges > 1 else {
            return nil
        }

        return nsLine.substring(with: match.range(at: 1))
    }

    private func extractQuotedName(from message: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"'([^']+)'"#, options: []) else {
            return nil
        }

        let nsMessage = message as NSString
        guard let match = regex.firstMatch(in: message, range: NSRange(location: 0, length: nsMessage.length)),
              match.numberOfRanges > 1 else {
            return nil
        }

        return nsMessage.substring(with: match.range(at: 1))
    }

    private func guessDeclarationName(from sourceLine: String) -> String? {
        let patterns = [
            #"(?:const|let|var|function|class|interface|type|enum)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            if let name = firstCapture(in: sourceLine, using: regex) {
                return name
            }
        }

        return nil
    }

    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func stripComments(from content: String) -> String {
        enum Mode {
            case normal
            case lineComment
            case blockComment
            case singleQuote
            case doubleQuote
            case templateString
        }

        var result = ""
        var mode: Mode = .normal
        var previousCharacter: Character?
        let characters = Array(content)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            let nextCharacter = index + 1 < characters.count ? characters[index + 1] : nil

            switch mode {
            case .normal:
                if character == "/", nextCharacter == "/" {
                    mode = .lineComment
                    result.append(" ")
                    index += 1
                } else if character == "/", nextCharacter == "*" {
                    mode = .blockComment
                    result.append(" ")
                    index += 1
                } else {
                    result.append(character)
                    if character == "'" {
                        mode = .singleQuote
                    } else if character == "\"" {
                        mode = .doubleQuote
                    } else if character == "`" {
                        mode = .templateString
                    }
                }

            case .lineComment:
                if character == "\n" {
                    mode = .normal
                    result.append("\n")
                } else {
                    result.append(" ")
                }

            case .blockComment:
                if character == "*", nextCharacter == "/" {
                    mode = .normal
                    result.append(" ")
                    index += 1
                } else if character == "\n" {
                    result.append("\n")
                } else {
                    result.append(" ")
                }

            case .singleQuote:
                result.append(character)
                if character == "'" && previousCharacter != "\\" {
                    mode = .normal
                }

            case .doubleQuote:
                result.append(character)
                if character == "\"" && previousCharacter != "\\" {
                    mode = .normal
                }

            case .templateString:
                result.append(character)
                if character == "`" && previousCharacter != "\\" {
                    mode = .normal
                }
            }

            previousCharacter = character
            index += 1
        }

        return result
    }

    private func deduplicate(results: [UnusedCodeResult]) -> [UnusedCodeResult] {
        var seen = Set<String>()
        var deduplicated: [UnusedCodeResult] = []

        for result in results {
            let key = "\(result.location)|\(result.name)"
            if seen.insert(key).inserted {
                deduplicated.append(result)
            }
        }

        return deduplicated.sorted {
            if $0.location == $1.location {
                return $0.name < $1.name
            }
            return $0.location < $1.location
        }
    }
}

private extension JavaScriptAnalyzer {
    struct SourceFile {
        let path: String
        let relativePath: String
        let content: String
        let searchableContent: String
        let lines: [String]
        let isDeclarationFile: Bool
    }

    struct Declaration {
        enum SearchScope {
            case file
            case project
        }

        let kind: String
        let name: String
        let location: String
        let hints: [String]
        let searchScope: SearchScope
    }

    struct Executable {
        let path: String
        let arguments: [String]
    }

    struct TypeScriptDiagnostic {
        let filePath: String
        let line: Int
        let code: String
        let message: String
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
