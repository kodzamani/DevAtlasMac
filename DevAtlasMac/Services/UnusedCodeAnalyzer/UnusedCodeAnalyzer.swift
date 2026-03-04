import Foundation
import AppKit

// MARK: - UnusedCodeAnalyzer (Main Coordinator)

class UnusedCodeAnalyzer: @unchecked Sendable {
    
    private var languageAnalyzers: [LanguageAnalyzer] = []
    
    init() {
        // Register language-specific analyzers
        languageAnalyzers.append(SwiftAnalyzer())
        languageAnalyzers.append(CSharpAnalyzer())
        languageAnalyzers.append(JavaScriptAnalyzer())
        languageAnalyzers.append(DartAnalyzer())
    }
    
    func analyze(projectPath: String) async throws -> [UnusedCodeResult] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Detect project language and use appropriate analyzer
                    let results = try self.analyzeWithLanguageDetection(at: projectPath)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func analyzeWithLanguageDetection(at path: String) throws -> [UnusedCodeResult] {
        let detectedLanguage = detectPrimaryLanguage(at: path)
        
        // Find appropriate analyzer
        for analyzer in languageAnalyzers {
            if analyzer.languageName.lowercased() == detectedLanguage.lowercased() {
                return try analyzer.analyze(projectPath: path)
            }
        }
        
        // Default to Swift analyzer if no match found
        if let swiftAnalyzer = languageAnalyzers.first(where: { $0 is SwiftAnalyzer }) {
            return try swiftAnalyzer.analyze(projectPath: path)
        }
        
        throw AnalyzerError.unsupportedLanguage(detectedLanguage)
    }
    
    private func detectPrimaryLanguage(at path: String) -> String {
        let fm = FileManager.default
        var extensionCounts: [String: Int] = [:]
        
        guard let enumerator = fm.enumerator(atPath: path) else {
            return "Swift"
        }
        
        let skipDirs = Set(["node_modules", ".git", "bin", "obj", "build", "dist", ".next", ".nuxt",
                          "Pods", ".build", "vendor", ".cache", "deriveddata", ".dart_tool",
                          ".pub-cache", "android", "ios", "web", "linux", "macos", "windows"])
        
        while let file = enumerator.nextObject() as? String {
            // Skip directories
            if skipDirs.contains(where: { file.contains($0) }) {
                continue
            }
            
            let ext = (file as NSString).pathExtension.lowercased()
            
            switch ext {
            case "swift":
                extensionCounts["Swift", default: 0] += 1
            case "cs":
                extensionCounts["C#", default: 0] += 1
            case "js", "jsx", "ts", "tsx", "mjs", "cjs":
                extensionCounts["JavaScript", default: 0] += 1
            case "dart":
                extensionCounts["Dart", default: 0] += 1
            default:
                break
            }
        }
        
        // Find the most common language
        if let primary = extensionCounts.max(by: { $0.value < $1.value }) {
            return primary.key
        }
        
        return "Swift"
    }
    
    // MARK: - Markdown Generation
    
    func generateMarkdownTable(from results: [UnusedCodeResult]) -> String {
        guard !results.isEmpty else {
            return "No unused code found in the project. Great job!"
        }
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                font-size: 13px;
                color: #333333;
                line-height: 1.5;
                padding: 20px;
            }
            @media (prefers-color-scheme: dark) {
                body {
                    color: #dddddd;
                }
            }
            h3 {
                margin-top: 0;
                font-size: 18px;
                font-weight: 600;
            }
            blockquote {
                margin: 0 0 16px 0;
                padding: 8px 12px;
                border-left: 4px solid #007aff;
                background-color: rgba(0, 122, 255, 0.1);
                color: #555;
                border-radius: 4px;
            }
            @media (prefers-color-scheme: dark) {
                blockquote {
                    color: #aaa;
                }
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-top: 10px;
                font-size: 13px;
            }
            th, td {
                text-align: left;
                padding: 10px;
                border-bottom: 1px solid #e0e0e0;
            }
            @media (prefers-color-scheme: dark) {
                th, td {
                    border-bottom: 1px solid #444;
                }
            }
            th {
                background-color: rgba(0,0,0,0.03);
                font-weight: 600;
                color: #555;
            }
            @media (prefers-color-scheme: dark) {
                th {
                    background-color: rgba(255,255,255,0.05);
                    color: #ccc;
                }
            }
            code {
                background-color: rgba(0,0,0,0.05);
                padding: 2px 4px;
                border-radius: 4px;
                font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                font-size: 12px;
                color: #d1235b;
            }
            @media (prefers-color-scheme: dark) {
                code {
                    background-color: rgba(255,255,255,0.1);
                    color: #ff7ab2;
                }
            }
        </style>
        </head>
        <body>
        
        <h3>Unused Code Analysis</h3>

        <blockquote> Automatically generated analysis of unused declarations in the project.<br>
        Found <strong>\(results.count)</strong> potential unused items.</blockquote>

        <div style="width:100%; overflow-x:auto;">
        <table>
            <thead>
                <tr>
                    <th>Type</th>
                    <th>Name</th>
                    <th>Location</th>
                    <th>Hints</th>
                </tr>
            </thead>
            <tbody>
        """

        for result in results {
            let hintsText = result.hints.joined(separator: ", ")
            html += """
                <tr>
                    <td><code>\(result.kind)</code></td>
                    <td><strong>\(result.name)</strong></td>
                    <td><code>\(result.location)</code></td>
                    <td>\(hintsText)</td>
                </tr>
            """
        }

        html += """
            </tbody>
        </table>
        </div>
        </body>
        </html>
        """

        return html
    }

    func generateMarkdownList(from results: [UnusedCodeResult]) -> String {
        guard !results.isEmpty else {
            return "No unused code found in the project. Great job!"
        }
        
        var markdown = "### Unused Code Analysis\n\n"
        markdown += "> Automatically generated analysis of unused declarations in the project.\n"
        markdown += "> Found **\(results.count)** potential unused items.\n\n"
        
        markdown += "| Type | Name | Location | Hints |\n"
        markdown += "|------|------|----------|-------|\n"
        
        for result in results {
            let hintsText = result.hints.joined(separator: ", ")
            markdown += "| `\(result.kind)` | **\(result.name)** | `\(result.location)` | \(hintsText)\n"
        }
        
        return markdown
    }

    func generateRemovalPrompt(from results: [UnusedCodeResult], projectPath: String) -> String {
        guard !results.isEmpty else {
            return """
            Review the codebase at \(projectPath) and confirm there are no clearly unused declarations left to remove.
            """
        }

        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        let groupedResults = Dictionary(grouping: results, by: { $0.kind.lowercased() })
        let preferredOrder = ["class", "struct", "interface", "protocol", "enum", "function", "method", "property", "variable", "typealias"]

        var sections: [String] = []

        for kind in preferredOrder {
            guard let items = groupedResults[kind], !items.isEmpty else { continue }
            let title = kind.capitalized + (items.count == 1 ? "" : "s")
            let lines = items.map { item in
                let hints = item.hints.joined(separator: ", ")
                return "- \(item.name) (\(item.location))" + (hints.isEmpty ? "" : " - \(hints)")
            }
            sections.append("\(title):\n" + lines.joined(separator: "\n"))
        }

        let remainingKinds = groupedResults.keys
            .filter { !preferredOrder.contains($0) }
            .sorted()

        for kind in remainingKinds {
            guard let items = groupedResults[kind], !items.isEmpty else { continue }
            let title = kind.capitalized + (items.count == 1 ? "" : "s")
            let lines = items.map { item in
                let hints = item.hints.joined(separator: ", ")
                return "- \(item.name) (\(item.location))" + (hints.isEmpty ? "" : " - \(hints)")
            }
            sections.append("\(title):\n" + lines.joined(separator: "\n"))
        }

        return """
        SYSTEM ROLE:
        You are a senior refactoring agent operating in deterministic cleanup mode. Your job is to remove verified dead code while preserving runtime behavior.

        PROJECT:
        Name: "\(projectName)"
        Path: "\(projectPath)"

        GOAL:
        For EACH symbol listed below, perform a full-project static reference search across the repository. If there are ZERO references, remove it.

        EXECUTION RULES:
        1) Perform a global reference search across ALL files (source, tests, configs, scripts), including barrel exports (index.ts), re-exports, and registry/config wiring.
        2) If a symbol has zero references (or only self-references) -> DELETE the declaration.
        3) After deletion, remove now-dead imports, exports, and any barrel-file entries that referenced the symbol.
        4) IMPORTANT: Exported status does NOT imply usage. If an exported symbol has zero references in this repo, it MUST be removed (and its export removed too).
        5) ONLY keep a symbol if you find concrete evidence of non-static usage, such as:
           - string-based lookup (e.g., accessing by name)
           - framework conventions requiring the symbol name
           - generated code hooks
           If kept, you MUST provide the exact file and line(s) proving this usage.
        6) Do not ask for confirmation. Apply the cleanup immediately.
        7) Do not invent usage. If you cannot find references, treat it as unused and remove it.

        POTENTIALLY UNUSED ITEMS (inspect one-by-one):
        \(sections.joined(separator: "\n\n"))

        AFTER CLEANUP, OUTPUT:
        - Removed symbols (name + file)
        - Modified files
        - Preserved/risky items + exact evidence (file:line)
        - Follow-ups: run typecheck/lint/tests/build and report failures
        """
    }
}
