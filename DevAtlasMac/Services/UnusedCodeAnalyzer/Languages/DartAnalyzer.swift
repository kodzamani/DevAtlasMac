import Foundation

// MARK: - Dart/Flutter Analyzer

class DartAnalyzer: LanguageAnalyzer {
    let languageName = "Dart"
    
    func analyze(projectPath: String) throws -> [UnusedCodeResult] {
        print("DartAnalyzer: Starting analysis for \(projectPath)")
        
        var results = try dartRegexAnalysis(at: projectPath)
        print("DartAnalyzer: dartRegexAnalysis returned \(results.count) results")
        
        // Analyze pubspec.yaml for unused packages and assets
        let pubspecResults = try analyzePubspec(at: projectPath)
        print("DartAnalyzer: pubspec analysis returned \(pubspecResults.count) results")
        results.append(contentsOf: pubspecResults)
        
        print("DartAnalyzer: Total results: \(results.count)")
        
        return results
    }
    
    // MARK: - Pubspec Analysis
    
    private func analyzePubspec(at path: String) throws -> [UnusedCodeResult] {
        var results: [UnusedCodeResult] = []
        
        // Find pubspec.yaml
        let pubspecPath = (path as NSString).appendingPathComponent("pubspec.yaml")
        guard FileManager.default.fileExists(atPath: pubspecPath),
              let pubspecContent = try? String(contentsOfFile: pubspecPath, encoding: .utf8) else {
            return results
        }
        
        print("DartAnalyzer: Found pubspec.yaml at \(pubspecPath)")
        
        // Parse dependencies and assets
        let dependencies = parsePubspecDependencies(pubspecContent)
        let assets = parsePubspecAssets(pubspecContent)
        
        print("DartAnalyzer: Found dependencies: \(dependencies)")
        
        // Collect all Dart file contents for import checking
        var allDartFilesContent = ""
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return results
        }
        
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".dart") && 
               !file.contains("node_modules/") && 
               !file.contains(".pub-cache/") &&
               !file.contains("build/") &&
               !file.contains(".dart_tool/") &&
               !file.contains("/ios/") &&
               !file.contains("/android/") &&
               !file.contains("/web/") &&
               !file.contains("/linux/") &&
               !file.contains("/macos/") &&
               !file.contains("/windows/") &&
               !file.contains("/test/") &&
               !file.hasPrefix("ios/") &&
               !file.hasPrefix("android/") &&
               !file.hasPrefix("web/") &&
               !file.hasPrefix("linux/") &&
               !file.hasPrefix("macos/") &&
               !file.hasPrefix("windows/") &&
               !file.hasPrefix("test/") {
                let fullPath = (path as NSString).appendingPathComponent(file)
                if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                    allDartFilesContent += content + "\n"
                }
            }
        }
        
        // Check unused packages
        results.append(contentsOf: checkUnusedPackages(dependencies, in: allDartFilesContent, pubspecPath: pubspecPath))
        
        // Check unused assets
        results.append(contentsOf: checkUnusedAssets(assets, in: allDartFilesContent, projectPath: path, pubspecPath: pubspecPath))
        
        return results
    }
    
    private func parsePubspecDependencies(_ content: String) -> [String] {
        var dependencies: [String] = []
        
        // Skip these packages
        let skipPackages = ["flutter", "flutter_test", "sdk"]
        
        let lines = content.components(separatedBy: .newlines)
        var inDependenciesSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Find section start
            if trimmed.hasPrefix("dependencies:") {
                inDependenciesSection = true
                continue
            }
            if trimmed.hasPrefix("dev_dependencies:") {
                inDependenciesSection = true
                continue
            }
            
            // End of dependencies sections - check for top-level keys
            if inDependenciesSection && !line.hasPrefix(" ") && !line.hasPrefix("\t") && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                // If line doesn't start with space and is a top-level key, end section
                if trimmed.hasSuffix(":") && !trimmed.hasPrefix("dependencies") && !trimmed.hasPrefix("dev_dependencies") {
                    inDependenciesSection = false
                }
            }
            
            // Only process in dependency sections
            if inDependenciesSection && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                // Check for 2-space indent (dependency items) - NOT 4-space (nested)
                if line.hasPrefix("  ") && !line.hasPrefix("    ") {
                    // Find package name before colon
                    if let colonIndex = trimmed.firstIndex(of: ":") {
                        var packageName = String(trimmed[..<colonIndex])
                        packageName = packageName.trimmingCharacters(in: .whitespaces)
                        
                        // Skip if empty or in skip list
                        if !packageName.isEmpty && !skipPackages.contains(packageName) {
                            // Skip if contains space
                            if !packageName.contains(" ") {
                                dependencies.append(packageName)
                            }
                        }
                    }
                }
            }
        }
        
        return dependencies
    }
    
    private func parsePubspecAssets(_ content: String) -> [String] {
        var assets: [String] = []
        var inAssets = false
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("assets:") {
                inAssets = true
                continue
            }
            
            if inAssets {
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }
                
                if trimmed.hasPrefix("- ") {
                    var assetPath = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    
                    // remove quotes if any
                    assetPath = assetPath.replacingOccurrences(of: "\"", with: "")
                    assetPath = assetPath.replacingOccurrences(of: "'", with: "")
                    
                    if let commentIndex = assetPath.firstIndex(of: "#") {
                        assetPath = String(assetPath[..<commentIndex]).trimmingCharacters(in: .whitespaces)
                    }
                    if !assetPath.isEmpty {
                        assets.append(assetPath)
                    }
                } else {
                    // Any non-empty, non-comment line that doesn't start with "- " means we're out of assets list
                    inAssets = false
                }
            }
        }
        
        return assets
    }
    
    private func checkUnusedPackages(_ packages: [String], in content: String, pubspecPath _: String) -> [UnusedCodeResult] {
        var results: [UnusedCodeResult] = []
        
        print("DartAnalyzer: Checking packages in content (first 200 chars): \(String(content.prefix(200)))")
        
        for package in packages {
            // Skip flutter SDK and common packages
            let skipPackages = Set(["flutter", "flutter_test", "meta", "collection", "async"])
            if skipPackages.contains(package) {
                continue
            }
            
            // Simple check: look for package name in import statements
            let importPattern = "package:\(package)"
            let isUsed = content.contains(importPattern)
            
            if !isUsed {
                results.append(UnusedCodeResult(
                    kind: "package",
                    name: package,
                    location: "pubspec.yaml",
                    hints: ["Package defined but not imported in any Dart file"]
                ))
            }
        }
        
        print("DartAnalyzer: Found \(results.count) unused packages")
        
        return results
    }
    
    private func checkUnusedAssets(_ assets: [String], in content: String, projectPath _: String, pubspecPath: String) -> [UnusedCodeResult] {
        var results: [UnusedCodeResult] = []
        
        let fileManager = FileManager.default
        let pubspecDir = (pubspecPath as NSString).deletingLastPathComponent
        
        for assetPath in assets {
            // Handle directory patterns like "assets/images/"
            let fullAssetPath = (pubspecDir as NSString).appendingPathComponent(assetPath)
            
            var isReferenced = false
            
            // Check if it's a directory
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fullAssetPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Check all files in directory
                    if let enumerator = fileManager.enumerator(atPath: fullAssetPath) {
                        while let file = enumerator.nextObject() as? String {
                            let fileName = (file as NSString).lastPathComponent
                            // Check for various image/asset references
                            let patterns = [
                                "'\(assetPath)\(fileName)'",
                                "\"\(assetPath)\(fileName)\"",
                                "'\(assetPath)\(fileName)//g'",
                                "\"\(assetPath)\(fileName)//g\"",
                                fileName
                            ]
                            for pattern in patterns {
                                if content.contains(pattern) {
                                    isReferenced = true
                                    break
                                }
                            }
                            if isReferenced { break }
                        }
                    }
                } else {
                    // Single file - check if referenced
                    let fileName = (assetPath as NSString).lastPathComponent
                    if content.contains(fileName) || content.contains(assetPath) {
                        isReferenced = true
                    }
                }
            }
            
            // Check for Image.asset, NetworkImage, etc. patterns
            if !isReferenced {
                let assetName = (assetPath as NSString).lastPathComponent
                let nameWithoutExt = (assetName as NSString).deletingPathExtension
                
                let referencePatterns = [
                    "Image.asset(\"\(assetPath)",
                    "Image.asset('\(assetPath)",
                    "NetworkImage(\"\(assetPath)",
                    "NetworkImage('\(assetPath)",
                    "AssetImage(\"\(assetPath)",
                    "AssetImage('\(assetPath)",
                    nameWithoutExt
                ]
                
                for pattern in referencePatterns {
                    if content.contains(pattern) {
                        isReferenced = true
                        break
                    }
                }
            }
            
            if !isReferenced {
                results.append(UnusedCodeResult(
                    kind: "asset",
                    name: assetPath,
                    location: "pubspec.yaml",
                    hints: ["Asset defined but not referenced in code"]
                ))
            }
        }
        
        return results
    }
    
    private func dartRegexAnalysis(at path: String) throws -> [UnusedCodeResult] {
        var results: [UnusedCodeResult] = []
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return results
        }
        
        var files: [String] = []
        
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".dart") && 
               !file.contains("node_modules/") && 
               !file.contains(".pub-cache/") &&
               !file.contains("build/") &&
               !file.contains(".dart_tool/") &&
               !file.contains("/ios/") &&
               !file.contains("/android/") &&
               !file.contains("/web/") &&
               !file.contains("/linux/") &&
               !file.contains("/macos/") &&
               !file.contains("/windows/") &&
               !file.hasPrefix("ios/") &&
               !file.hasPrefix("android/") &&
               !file.hasPrefix("web/") &&
               !file.hasPrefix("linux/") &&
               !file.hasPrefix("macos/") &&
               !file.hasPrefix("windows/") {
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
        
        // MARK: - Dart/Flutter Regex Patterns
        
        // 1. Class declarations (including abstract)
        let classRegex = try? NSRegularExpression(
            pattern: #"(?:abstract\s+)?class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // 2. Mixin declarations
        let mixinRegex = try? NSRegularExpression(
            pattern: #"mixin\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // 3. Extension declarations
        let extensionRegex = try? NSRegularExpression(
            pattern: #"extension\s+(?:[a-zA-Z_][a-zA-Z0-9_]*\s+)?on\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // 4. Enum declarations
        let enumRegex = try? NSRegularExpression(
            pattern: #"enum\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // 5. Typedef declarations
        let typedefRegex = try? NSRegularExpression(
            pattern: #"typedef\s+(?:[a-zA-Z_][a-zA-Z0-9_<>,\s]*\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*="#,
            options: []
        )
        
        // 6. Top-level function declarations (functions outside classes)
        let topLevelFuncRegex = try? NSRegularExpression(
            pattern: #"(?:void|int|double|String|bool|dynamic|var|final|const|Stream|Future|Widget)?\s*(?:\?\s*)?(?:\w+)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)\s*(?:async)?\s*\{"#,
            options: []
        )
        
        // 7. Top-level variable declarations (final, const, var)
        let topLevelVarRegex = try? NSRegularExpression(
            pattern: #"(?:static\s+)?(?:final|const|var)\s+(?:<[^>]+>\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*="#,
            options: []
        )
        
        // 8. Private method declarations (methods starting with _)
        let privateMethodRegex = try? NSRegularExpression(
            pattern: #"(?:void|int|double|String|bool|dynamic|var|final|Widget|Stream|Future|static)?\s*(?:\?\s*)?\s+_([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#,
            options: []
        )
        
        // 9. Private variable declarations
        let privateVarRegex = try? NSRegularExpression(
            pattern: #"(?:final|const|var)\s+_([a-zA-Z_][a-zA-Z0-9_]*)"#,
            options: []
        )
        
        // 10. Static method declarations
        let staticMethodRegex = try? NSRegularExpression(
            pattern: #"static\s+(?:void|int|double|String|bool|dynamic|Widget|Stream|Future)?\s*(?:\?\s*)?\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#,
            options: []
        )
        
        // MARK: - Flutter-Specific Patterns
        
        // 11. StatelessWidget
        let statelessWidgetRegex = try? NSRegularExpression(
            pattern: #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+extends\s+StatelessWidget"#,
            options: []
        )
        
        // 12. StatefulWidget
        let statefulWidgetRegex = try? NSRegularExpression(
            pattern: #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+extends\s+StatefulWidget"#,
            options: []
        )
        
        // 13. State class (extends State<WidgetName>)
        let stateClassRegex = try? NSRegularExpression(
            pattern: #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+extends\s+State<[^>]+>"#,
            options: []
        )
        
        // 14. ChangeNotifier
        let changeNotifierRegex = try? NSRegularExpression(
            pattern: #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+extends\s+ChangeNotifier"#,
            options: []
        )
        
        // 15. Provider/ChangeNotifierProvider
        let providerRegex = try? NSRegularExpression(
            pattern: #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+extends\s+(?:ChangeNotifier)?Provider<[^>]+>"#,
            options: []
        )
        
        // 16. InheritedWidget
        let inheritedWidgetRegex = try? NSRegularExpression(
            pattern: #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+extends\s+InheritedWidget"#,
            options: []
        )
        
        // MARK: - Dart/Flutter Built-in Types to Skip
        
        let dartBuiltInTypes = Set([
            // Primitives
            "String", "int", "double", "num", "bool", "dynamic", "void", "Never",
            "Object", "Function", "Symbol", "Type", "Null",
            
            // Collections
            "List", "Map", "Set", "Iterable", "Collection", "Queue", "Stack",
            
            // Async
            "Future", "Stream", "FutureOr", "StreamSubscription",
            
            // Flutter Core
            "Widget", "BuildContext", "State", "StatefulWidget", "StatelessWidget",
            "Key", "Element", "RenderObject", "RenderObjectWidget",
            "AppBar", "Scaffold", "Container", "Text", "Image", "Icon",
            "Center", "Column", "Row", "Stack", "Padding", "Margin",
            "TextStyle", "BoxDecoration", "Border", "EdgeInsets",
            "Navigator", "Route", "MaterialPageRoute",
            "Theme", "ThemeData", "Colors", "Icons",
            
            // Provider
            "ChangeNotifier", "Provider", "Consumer", "Selector",
            "ChangeNotifierProvider", "FutureProvider", "StreamProvider",
            
            // State Management
            "InheritedWidget", "InheritedModel", "ProxyWidget",
            
            // Lifecycle
            "initState", "dispose", "build", "didChangeDependencies",
            "didUpdateWidget", "setState",
            
            // Common
            "main", "runApp", "print", "toString", "hashCode", "==",
            "context", "mounted", "widget", "didUpdateWidget"
        ])
        
        for file in files {
            guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            
            var classes: [(name: String, line: Int)] = []
            var mixins: [(name: String, line: Int)] = []
            var extensions: [(name: String, line: Int)] = []
            var enums: [(name: String, line: Int)] = []
            var typedefs: [(name: String, line: Int)] = []
            var topLevelFuncs: [(name: String, line: Int)] = []
            var topLevelVars: [(name: String, line: Int)] = []
            var privateMethods: [(name: String, line: Int)] = []
            var privateVars: [(name: String, line: Int)] = []
            var staticMethods: [(name: String, line: Int)] = []
            
            // Flutter-specific
            var statelessWidgets: [(name: String, line: Int)] = []
            var statefulWidgets: [(name: String, line: Int)] = []
            var stateClasses: [(name: String, line: Int)] = []
            var changeNotifiers: [(name: String, line: Int)] = []
            var providers: [(name: String, line: Int)] = []
            var inheritedWidgets: [(name: String, line: Int)] = []
            
            for (index, line) in lines.enumerated() {
                let nsLine = line as NSString
                let lineNumber = index + 1
                
                // Skip lines with only whitespace, comments, or attributes
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || 
                   trimmed.hasPrefix("//") || 
                   trimmed.hasPrefix("/*") || 
                   trimmed.hasPrefix("*") ||
                   trimmed.hasPrefix("@") ||
                   trimmed.hasPrefix("import ") ||
                   trimmed.hasPrefix("export ") ||
                   trimmed.hasPrefix("part ") ||
                   trimmed.hasPrefix("#if") ||
                   trimmed.hasPrefix("#else") ||
                   trimmed.hasPrefix("#endif") {
                    continue
                }
                
                // Class detection
                if let classMatch = classRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: classMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) && !name.hasPrefix("_") {
                        classes.append((name: name, line: lineNumber))
                    }
                }
                
                // Mixin detection
                if let mixinMatch = mixinRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: mixinMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) && !name.hasPrefix("_") {
                        mixins.append((name: name, line: lineNumber))
                    }
                }
                
                // Extension detection
                if let extMatch = extensionRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: extMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        extensions.append((name: name, line: lineNumber))
                    }
                }
                
                // Enum detection
                if let enumMatch = enumRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: enumMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) && !name.hasPrefix("_") {
                        enums.append((name: name, line: lineNumber))
                    }
                }
                
                // Typedef detection
                if let typedefMatch = typedefRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: typedefMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) && !name.hasPrefix("_") {
                        typedefs.append((name: name, line: lineNumber))
                    }
                }
                
                // Top-level function detection (simple pattern)
                if let funcMatch = topLevelFuncRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: funcMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) && !name.hasPrefix("_") && name != "main" {
                        topLevelFuncs.append((name: name, line: lineNumber))
                    }
                }
                
                // Top-level variable detection
                if let varMatch = topLevelVarRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: varMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) && !name.hasPrefix("_") {
                        topLevelVars.append((name: name, line: lineNumber))
                    }
                }
                
                // Private method detection
                if let methodMatch = privateMethodRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: methodMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        privateMethods.append((name: name, line: lineNumber))
                    }
                }
                
                // Private variable detection
                if let privVarMatch = privateVarRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: privVarMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        privateVars.append((name: name, line: lineNumber))
                    }
                }
                
                // Static method detection
                if let staticMatch = staticMethodRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: staticMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        staticMethods.append((name: name, line: lineNumber))
                    }
                }
                
                // Flutter-specific: StatelessWidget
                if let swMatch = statelessWidgetRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: swMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        statelessWidgets.append((name: name, line: lineNumber))
                    }
                }
                
                // Flutter-specific: StatefulWidget
                if let fwMatch = statefulWidgetRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: fwMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        statefulWidgets.append((name: name, line: lineNumber))
                    }
                }
                
                // Flutter-specific: State class
                if let stateMatch = stateClassRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: stateMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) && !name.hasSuffix("State") {
                        stateClasses.append((name: name, line: lineNumber))
                    }
                }
                
                // Flutter-specific: ChangeNotifier
                if let cnMatch = changeNotifierRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: cnMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        changeNotifiers.append((name: name, line: lineNumber))
                    }
                }
                
                // Flutter-specific: Provider
                if let provMatch = providerRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: provMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        providers.append((name: name, line: lineNumber))
                    }
                }
                
                // Flutter-specific: InheritedWidget
                if let iwMatch = inheritedWidgetRegex?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                    let name = nsLine.substring(with: iwMatch.range(at: 1))
                    if !dartBuiltInTypes.contains(name) {
                        inheritedWidgets.append((name: name, line: lineNumber))
                    }
                }
            }
            
            let shortFile = (file as NSString).lastPathComponent
            
            // MARK: - Cross-File Usage Analysis for Type Declarations
            
            // Classes - check in ALL project files
            for cls in classes {
                let usagePattern = "\\b\(cls.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
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
            
            // Mixins - check in ALL project files
            for mix in mixins {
                let usagePattern = "with\\s+\(mix.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.isEmpty {
                        results.append(UnusedCodeResult(
                            kind: "mixin",
                            name: mix.name,
                            location: "\(shortFile):\(mix.line)",
                            hints: ["Mixin appears unused across project"]
                        ))
                    }
                }
            }
            
            // Extensions - check in ALL project files
            for ext in extensions {
                let usagePattern = "\\b\(ext.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "extension",
                            name: ext.name,
                            location: "\(shortFile):\(ext.line)",
                            hints: ["Extension appears unused across project"]
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
            
            // Typedefs - check in ALL project files
            for td in typedefs {
                let usagePattern = "\\b\(td.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "typedef",
                            name: td.name,
                            location: "\(shortFile):\(td.line)",
                            hints: ["Typedef appears unused across project"]
                        ))
                    }
                }
            }
            
            // Top-level functions - check in ALL project files
            for topFunc in topLevelFuncs {
                let usagePattern = "\\b\(topFunc.name)\\s*\\("
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.isEmpty {
                        results.append(UnusedCodeResult(
                            kind: "function",
                            name: topFunc.name,
                            location: "\(shortFile):\(topFunc.line)",
                            hints: ["Top-level function appears unused"]
                        ))
                    }
                }
            }
            
            // Top-level variables - check in ALL project files
            for topVar in topLevelVars {
                let usagePattern = "\\b\(topVar.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "variable",
                            name: topVar.name,
                            location: "\(shortFile):\(topVar.line)",
                            hints: ["Top-level variable appears unused"]
                        ))
                    }
                }
            }
            
            // MARK: - Local File Analysis (Private/Static members)
            
            for privMeth in privateMethods {
                let usagePattern = "_?\(privMeth.name)\\s*\\("
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: content, range: NSRange(location: 0, length: (content as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "method",
                            name: privMeth.name,
                            location: "\(shortFile):\(privMeth.line)",
                            hints: ["Private method appears unused"]
                        ))
                    }
                }
            }
            
            for privVar in privateVars {
                let usagePattern = "_?\(privVar.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: content, range: NSRange(location: 0, length: (content as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "variable",
                            name: privVar.name,
                            location: "\(shortFile):\(privVar.line)",
                            hints: ["Private variable appears unused"]
                        ))
                    }
                }
            }
            
            for staticMeth in staticMethods {
                let usagePattern = "\\b\(staticMeth.name)\\s*\\("
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: content, range: NSRange(location: 0, length: (content as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "static method",
                            name: staticMeth.name,
                            location: "\(shortFile):\(staticMeth.line)",
                            hints: ["Static method appears unused"]
                        ))
                    }
                }
            }
            
            // MARK: - Flutter-Specific Analysis
            
            // StatelessWidget - check in ALL project files
            for sw in statelessWidgets {
                let usagePattern = "\\b\(sw.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "StatelessWidget",
                            name: sw.name,
                            location: "\(shortFile):\(sw.line)",
                            hints: ["StatelessWidget appears unused across project"]
                        ))
                    }
                }
            }
            
            // StatefulWidget - check in ALL project files
            for fw in statefulWidgets {
                let usagePattern = "\\b\(fw.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "StatefulWidget",
                            name: fw.name,
                            location: "\(shortFile):\(fw.line)",
                            hints: ["StatefulWidget appears unused across project"]
                        ))
                    }
                }
            }
            
            // State class - check in ALL project files
            for state in stateClasses {
                let usagePattern = "State<\(state.name)>"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.isEmpty {
                        results.append(UnusedCodeResult(
                            kind: "State",
                            name: state.name,
                            location: "\(shortFile):\(state.line)",
                            hints: ["State class appears unused (not attached to widget)"]
                        ))
                    }
                }
            }
            
            // ChangeNotifier - check in ALL project files
            for cn in changeNotifiers {
                let usagePattern = "Provider<\\(cn.name)>|ChangeNotifierProvider<\\(cn.name)>|context\\.read<\\(cn.name)\\>"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.isEmpty {
                        results.append(UnusedCodeResult(
                            kind: "ChangeNotifier",
                            name: cn.name,
                            location: "\(shortFile):\(cn.line)",
                            hints: ["ChangeNotifier appears unused (not provided)"]
                        ))
                    }
                }
            }
            
            // Provider - check in ALL project files
            for prov in providers {
                let usagePattern = "Provider<\\(prov.name)>|ChangeNotifierProvider<\\(prov.name)>"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.isEmpty {
                        results.append(UnusedCodeResult(
                            kind: "Provider",
                            name: prov.name,
                            location: "\(shortFile):\(prov.line)",
                            hints: ["Provider appears unused"]
                        ))
                    }
                }
            }
            
            // InheritedWidget - check in ALL project files
            for iw in inheritedWidgets {
                let usagePattern = "\\b\(iw.name)\\b"
                if let regex = try? NSRegularExpression(pattern: usagePattern, options: []) {
                    let matches = regex.matches(in: combinedContent, range: NSRange(location: 0, length: (combinedContent as NSString).length))
                    if matches.count <= 1 {
                        results.append(UnusedCodeResult(
                            kind: "InheritedWidget",
                            name: iw.name,
                            location: "\(shortFile):\(iw.line)",
                            hints: ["InheritedWidget appears unused across project"]
                        ))
                    }
                }
            }
        }
        
        return results
    }
}
