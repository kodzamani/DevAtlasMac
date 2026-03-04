import Foundation

// MARK: - C# Analyzer

class CSharpAnalyzer: LanguageAnalyzer {
    let languageName = "C#"
    
    func analyze(projectPath: String) throws -> [UnusedCodeResult] {
        return try csharpRegexAnalysis(at: projectPath)
    }
    
    private func csharpRegexAnalysis(at path: String) throws -> [UnusedCodeResult] {
        var results: [UnusedCodeResult] = []
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return results
        }
        
        var files: [String] = []
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".cs") && 
               !file.contains("obj/") && 
               !file.contains("bin/") &&
               !file.contains("Migrations/") &&
               !file.hasSuffix("ModelSnapshot.cs") {
                files.append((path as NSString).appendingPathComponent(file))
            }
        }
        
        // Collect all file contents for cross-file analysis
        var allFileContents: [String: String] = [:]
        for file in files {
            if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                allFileContents[file] = content
            }
        }
        
        // Combined content for cross-file search
        let combinedContent = allFileContents.values.joined(separator: "\n")
        
        // C# patterns for unused code
        // 1. Private fields
        let privateFieldRegex = try? NSRegularExpression(
            pattern: #"private\s+(?:readonly\s+)?(?:[\w<>]+\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*;"#,
            options: []
        )
        
        // 2. Private methods
        let privateMethodRegex = try? NSRegularExpression(
            pattern: #"private\s+[\w<>]+\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#,
            options: []
        )
        
        // 3. Private classes (kept for backward compatibility)
        let privateClassRegex = try? NSRegularExpression(
            pattern: #"private\s+(?:partial\s+)?class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // ========== NEW: All type declarations with all access modifiers ==========
        
        // Classes - ALL access modifiers (public, private, internal, protected, or no modifier)
        let classRegex = try? NSRegularExpression(
            pattern: #"(?:public|private|internal|protected|internal protected|private protected)?\s*(?:partial\s+)?class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // Structs - ALL access modifiers
        let structRegex = try? NSRegularExpression(
            pattern: #"(?:public|private|internal|protected)?\s*struct\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // Enums - ALL access modifiers
        let enumRegex = try? NSRegularExpression(
            pattern: #"(?:public|private|internal|protected)?\s*enum\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // Interfaces - ALL access modifiers
        let interfaceRegex = try? NSRegularExpression(
            pattern: #"(?:public|private|internal|protected)?\s*interface\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // 4. Private properties
        let privatePropertyRegex = try? NSRegularExpression(
            pattern: #"private\s+[\w<>]+\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\{\s*get"#,
            options: []
        )
        
        // 5. Local variables (var, int, string, bool, double, float, decimal, long, short, byte, char, object)
        let localVarRegex = try? NSRegularExpression(
            pattern: #"(?:var|int|string|bool|double|float|decimal|long|short|byte|char|object)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*="#,
            options: []
        )
        
        for file in files {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            
            var privateFields: [(name: String, line: Int)] = []
            var privateMethods: [(name: String, line: Int)] = []
            var privateClasses: [(name: String, line: Int)] = []
            var privateProperties: [(name: String, line: Int)] = []
            var localVars: [(name: String, line: Int)] = []
            
            // New type arrays
            var classes: [(name: String, line: Int)] = []
            var structs: [(name: String, line: Int)] = []
            var enums: [(name: String, line: Int)] = []
            var interfaces: [(name: String, line: Int)] = []
            
            for (index, line) in lines.enumerated() {
                let nsLine = line as NSString
                let lineNumber = index + 1
                
                // Skip attribute declarations and lines with only whitespace
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("[") {
                    continue
                }
                
                if let fieldMatch = privateFieldRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: fieldMatch.range(at: 1))
                    // Skip common naming patterns that might be false positives
                    if !name.hasPrefix("_") && name.count > 1 {
                        privateFields.append((name: name, line: lineNumber))
                    }
                }
                
                if let methodMatch = privateMethodRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: methodMatch.range(at: 1))
                    privateMethods.append((name: name, line: lineNumber))
                }
                
                if let classMatch = privateClassRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: classMatch.range(at: 1))
                    privateClasses.append((name: name, line: lineNumber))
                }
                
                if let propertyMatch = privatePropertyRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: propertyMatch.range(at: 1))
                    privateProperties.append((name: name, line: lineNumber))
                }
                
                // Detect local variables
                if let varMatch = localVarRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: varMatch.range(at: 1))
                    // Skip common keywords and patterns
                    if name != "var" && name != "true" && name != "false" && name.count > 0 {
                        localVars.append((name: name, line: lineNumber))
                    }
                }
                
                // ========== NEW: Detect all types ==========
                
                // Skip common built-in and framework types
                let skipTypes = Set(["String", "Int32", "Int64", "Boolean", "Object", "List", "Dictionary", 
                                    "Task", "Action", "Func", "EventArgs", "Exception", "DateTime",
                                    "IEnumerable", "IList", "ICollection", "IDictionary"])
                
                // Classes
                if let classMatch = classRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: classMatch.range(at: 1))
                    if !skipTypes.contains(name) && !name.hasPrefix("_") {
                        classes.append((name: name, line: lineNumber))
                    }
                }
                
                // Structs
                if let structMatch = structRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: structMatch.range(at: 1))
                    if !skipTypes.contains(name) && !name.hasPrefix("_") {
                        structs.append((name: name, line: lineNumber))
                    }
                }
                
                // Enums
                if let enumMatch = enumRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: enumMatch.range(at: 1))
                    if !skipTypes.contains(name) && !name.hasPrefix("_") {
                        enums.append((name: name, line: lineNumber))
                    }
                }
                
                // Interfaces
                if let interfaceMatch = interfaceRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: interfaceMatch.range(at: 1))
                    if !skipTypes.contains(name) && !name.hasPrefix("_") {
                        interfaces.append((name: name, line: lineNumber))
                    }
                }
            }
            
            // Check usage for each type
            let shortFile = (file as NSString).lastPathComponent
            
            for field in privateFields {
                let usageCount = content.components(separatedBy: field.name).count - 1
                if usageCount <= 1 {
                    results.append(UnusedCodeResult(
                        kind: "field",
                        name: field.name,
                        location: "\(shortFile):\(field.line)",
                        hints: ["Private field appears unused"]
                    ))
                }
            }
            
            for method in privateMethods {
                // More lenient check for methods - look for invocation pattern
                let invokePattern = "\(method.name)("
                let usageCount = content.components(separatedBy: invokePattern).count - 1
                if usageCount == 0 {
                    results.append(UnusedCodeResult(
                        kind: "method",
                        name: method.name,
                        location: "\(shortFile):\(method.line)",
                        hints: ["Private method appears unused"]
                    ))
                }
            }
            
            for cls in privateClasses {
                let usageCount = content.components(separatedBy: cls.name).count - 1
                if usageCount <= 1 {
                    results.append(UnusedCodeResult(
                        kind: "class",
                        name: cls.name,
                        location: "\(shortFile):\(cls.line)",
                        hints: ["Private class appears unused"]
                    ))
                }
            }
            
            for prop in privateProperties {
                let usageCount = content.components(separatedBy: prop.name).count - 1
                if usageCount <= 1 {
                    results.append(UnusedCodeResult(
                        kind: "property",
                        name: prop.name,
                        location: "\(shortFile):\(prop.line)",
                        hints: ["Private property appears unused"]
                    ))
                }
            }
            
            // Check local variables - look for usage in the same file (excluding the declaration)
            for localVar in localVars {
                // Use word boundary for more accurate matching
                let pattern = "\\b\(localVar.name)\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let matches = regex.matches(in: content, range: NSRange(location: 0, length: (content as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "variable",
                            name: localVar.name,
                            location: "\(shortFile):\(localVar.line)",
                            hints: ["Local variable appears unused"]
                        ))
                    }
                }
            }
            
            // ========== NEW: Cross-file type usage check ==========
            
            // Classes - check in ALL project files
            for cls in classes {
                let usagePattern = "\\b\(cls.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    // If only found in declaration (1 match), it's unused
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "class",
                            name: cls.name,
                            location: "\(shortFile):\(cls.line)",
                            hints: ["Class appears unused across project"]
                        ))
                    }
                }
            }
            
            // Structs - check in ALL project files
            for str in structs {
                let usagePattern = "\\b\(str.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "struct",
                            name: str.name,
                            location: "\(shortFile):\(str.line)",
                            hints: ["Struct appears unused across project"]
                        ))
                    }
                }
            }
            
            // Enums - check in ALL project files
            for enm in enums {
                let usagePattern = "\\b\(enm.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "enum",
                            name: enm.name,
                            location: "\(shortFile):\(enm.line)",
                            hints: ["Enum appears unused across project"]
                        ))
                    }
                }
            }
            
            // Interfaces - check in ALL project files
            for intf in interfaces {
                let usagePattern = "\\b\(intf.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "interface",
                            name: intf.name,
                            location: "\(shortFile):\(intf.line)",
                            hints: ["Interface appears unused across project"]
                        ))
                    }
                }
            }
        }
        
        return results
    }
}
