import Foundation

// MARK: - Swift Analyzer

/// Finds unused Swift declarations without external tools.
///
/// Every `.swift` file in the project is tokenized; declarations made at file
/// and type scope are matched against every identifier reference in the
/// project (plus storyboards, XIBs, plists and Core Data models). The rules
/// lean towards precision: anything that may be reached implicitly — protocol
/// witnesses of framework protocols, `@objc` / Interface Builder members,
/// overrides, Codable storage, entry points — is retained rather than reported.
class SwiftAnalyzer: LanguageAnalyzer {
    let languageName = "Swift"

    // MARK: Configuration

    private static let skippedDirectories: Set<String> = [
        "build", "DerivedData", "Pods", "Carthage", "SourcePackages", "checkouts",
        "node_modules", "vendor", "Vendor"
    ]

    private static let skippedBundleExtensions: Set<String> = [
        "xcodeproj", "xcworkspace", "xcassets", "framework", "xcframework", "app", "bundle"
    ]

    private static let resourceExtensions: Set<String> = ["storyboard", "xib", "plist", "intentdefinition"]

    // MARK: Analysis

    func analyze(projectPath: String) throws -> [UnusedCodeResult] {
        let rootURL = URL(fileURLWithPath: projectPath).standardizedFileURL
        let files = collectFiles(at: rootURL)
        guard !files.swift.isEmpty else { return [] }

        var sources: [SourceFile] = []
        var scanner = SwiftDeclarationScanner()

        for url in files.swift {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let fileIndex = sources.count
            let tokens = SwiftSourceLexer.tokenize(text)
            scanner.scan(tokens: tokens, fileIndex: fileIndex)
            sources.append(SourceFile(
                relativePath: relativePath(of: url, root: rootURL),
                tokens: tokens,
                isTestFile: isTestFile(url, root: rootURL, text: text)
            ))
        }

        var references = ReferenceIndex(fileCount: sources.count)
        for (fileIndex, source) in sources.enumerated() {
            let excluded = scanner.nonReferenceTokens[fileIndex] ?? []
            for (tokenIndex, token) in source.tokens.enumerated()
            where token.kind == .identifier && !excluded.contains(tokenIndex) {
                references.add(token.text, fileIndex: fileIndex)
            }
        }
        for url in files.resources {
            references.addResourceReferences(from: url)
        }

        let context = RetentionContext(
            scanner: scanner,
            isLibraryPackage: FileManager.default.fileExists(
                atPath: rootURL.appendingPathComponent("Package.swift").path
            )
        )

        return scanner.declarations
            .filter { declaration in
                let source = sources[declaration.fileIndex]
                guard !source.isTestFile, source.relativePath != "Package.swift" else { return false }
                guard !context.isRetained(declaration) else { return false }
                return referenceCount(of: declaration, references: references, sources: sources, context: context) == 0
            }
            .sorted { lhs, rhs in
                let lhsPath = sources[lhs.fileIndex].relativePath
                let rhsPath = sources[rhs.fileIndex].relativePath
                return lhsPath != rhsPath ? lhsPath < rhsPath : lhs.line < rhs.line
            }
            .map { declaration in
                UnusedCodeResult(
                    kind: declaration.kind.rawValue,
                    name: declaration.name,
                    location: "\(sources[declaration.fileIndex].relativePath):\(declaration.line):\(declaration.column)",
                    hints: [declaration.isFilePrivate
                        ? "Private declaration is never referenced in its file"
                        : "Declaration is never referenced in the project"]
                )
            }
    }

    // MARK: Reference Counting

    private func referenceCount(
        of declaration: SwiftDeclaration,
        references: ReferenceIndex,
        sources: [SourceFile],
        context: RetentionContext
    ) -> Int {
        let total = declaration.isFilePrivate
            ? references.count(of: declaration.name, inFile: declaration.fileIndex)
            : references.count(of: declaration.name)

        guard total > 0, declaration.kind.isType, declaration.kind != .typealias else {
            return total
        }

        // A type that only mentions itself (`static let shared = Foo()`) is still unused:
        // discount references inside its own body and the bodies of its extensions.
        var selfReferences = 0
        for container in context.containers(named: declaration.name) {
            if declaration.isFilePrivate && container.fileIndex != declaration.fileIndex { continue }
            guard let start = container.bodyStart, let end = container.bodyEnd, start < end else { continue }

            let tokens = sources[container.fileIndex].tokens
            let excluded = context.nonReferenceTokens(inFile: container.fileIndex)
            for index in (start + 1)..<end where tokens[index].kind == .identifier
                && tokens[index].text == declaration.name && !excluded.contains(index) {
                selfReferences += 1
            }
        }
        return total - selfReferences
    }

    // MARK: Files

    private func collectFiles(at root: URL) -> (swift: [URL], resources: [URL]) {
        var swiftFiles: [URL] = []
        var resourceFiles: [URL] = []

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ([], [])
        }

        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let name = url.lastPathComponent
            let pathExtension = url.pathExtension

            if isDirectory {
                if Self.skippedDirectories.contains(name) || Self.skippedBundleExtensions.contains(pathExtension) {
                    enumerator.skipDescendants()
                }
                continue
            }

            if pathExtension == "swift" {
                swiftFiles.append(url)
            } else if Self.resourceExtensions.contains(pathExtension)
                        || (name == "contents" && url.deletingLastPathComponent().pathExtension == "xcdatamodel") {
                resourceFiles.append(url)
            }
        }

        return (swiftFiles, resourceFiles)
    }

    private func relativePath(of url: URL, root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : url.lastPathComponent
    }

    private func isTestFile(_ url: URL, root: URL, text: String) -> Bool {
        let components = relativePath(of: url, root: root).split(separator: "/").dropLast()
        if components.contains(where: { $0.hasSuffix("Tests") || $0 == "Test" || $0 == "Tests" }) {
            return true
        }
        let fileName = url.deletingPathExtension().lastPathComponent
        if fileName.hasSuffix("Tests") || fileName.hasSuffix("Test") {
            return true
        }
        return text.contains("import XCTest") || text.contains("import Testing")
    }
}

// MARK: - Retention Rules

private enum SwiftRetentionRules {
    /// Attributes that make a declaration reachable from outside Swift source.
    static let retainingAttributes: Set<String> = [
        "objc", "IBAction", "IBOutlet", "IBInspectable", "IBSegueAction", "IBDesignable",
        "NSManaged", "main", "UIApplicationMain", "NSApplicationMain", "Test", "Suite",
        "_cdecl", "_silgen_name", "_dynamicReplacement", "GKInspectable",
        // Property wrappers whose mere presence installs something.
        "NSApplicationDelegateAdaptor", "UIApplicationDelegateAdaptor", "WKApplicationDelegateAdaptor",
        "WKExtensionDelegateAdaptor"
    ]

    /// Members reached implicitly by the compiler or frameworks.
    static let implicitMemberNames: Set<String> = [
        "body", "id", "description", "debugDescription", "hash", "hashValue", "encode",
        "callAsFunction", "wrappedValue", "projectedValue", "allCases", "rawValue",
        "errorDescription", "failureReason", "recoverySuggestion", "helpAnchor",
        "makeBody", "makeCoordinator", "makeNSView", "updateNSView", "dismantleNSView",
        "makeUIView", "updateUIView", "dismantleUIView", "makeNSViewController",
        "updateNSViewController", "makeUIViewController", "updateUIViewController",
        "sizeThatFits", "previews", "defaultValue", "reduce", "main", "run", "perform",
        "unownedExecutor", "customMirror", "playgroundDescription", "debugQuickLookObject",
        "buildBlock", "buildExpression", "buildOptional", "buildEither", "buildArray",
        "buildLimitedAvailability", "buildFinalResult", "buildPartialBlock", "buildIf",
        "subscript"
    ]

    /// Conformances that do not imply framework-called members beyond `implicitMemberNames`.
    static let neutralConformances: Set<String> = [
        "Sendable", "Equatable", "Hashable", "Comparable", "Identifiable", "Error",
        "CustomStringConvertible", "CustomDebugStringConvertible", "CaseIterable",
        "Codable", "Decodable", "Encodable", "AnyObject", "class", "LocalizedError",
        "RawRepresentable", "unchecked"
    ]

    static let codableConformances: Set<String> = ["Codable", "Decodable", "Encodable"]

    /// Enums with these conformances may be created from raw or decoded values.
    static let valueBackedEnumConformances: Set<String> = [
        "String", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16",
        "UInt32", "UInt64", "Double", "Float", "Character", "Codable", "Decodable",
        "Encodable", "CaseIterable", "RawRepresentable", "NSNumber"
    ]

    /// Types the system discovers on its own (no source reference needed).
    static let systemDiscoveredConformances: Set<String> = [
        "PreviewProvider", "AppIntent", "AppShortcutsProvider", "AppEntity", "AppEnum",
        "WidgetBundle", "LiveActivityIntent", "ControlWidget", "XCTestCase"
    ]
}

// MARK: - Supporting Types

private struct SourceFile {
    let relativePath: String
    let tokens: [SwiftToken]
    let isTestFile: Bool
}

private struct ReferenceIndex {
    private var global: [String: Int] = [:]
    private var perFile: [[String: Int]]

    init(fileCount: Int) {
        perFile = Array(repeating: [:], count: fileCount)
    }

    mutating func add(_ name: String, fileIndex: Int) {
        increment(name, fileIndex: fileIndex)
        // Property-wrapper backing storage (`_value`) refers to `value`.
        if name.count > 1, name.hasPrefix("_") {
            increment(String(name.dropFirst()), fileIndex: fileIndex)
        }
    }

    /// Storyboards, XIBs, plists and Core Data models reference classes,
    /// outlets and actions by name.
    mutating func addResourceReferences(from url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        var current = ""
        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                global[current, default: 0] += 1
                current = ""
            }
        }
        if !current.isEmpty { global[current, default: 0] += 1 }
    }

    func count(of name: String) -> Int {
        global[name] ?? 0
    }

    func count(of name: String, inFile fileIndex: Int) -> Int {
        perFile[fileIndex][name] ?? 0
    }

    private mutating func increment(_ name: String, fileIndex: Int) {
        global[name, default: 0] += 1
        perFile[fileIndex][name, default: 0] += 1
    }
}

/// Decides which declarations must be kept even without a textual reference.
private struct RetentionContext {
    private let scanner: SwiftDeclarationScanner
    private let isLibraryPackage: Bool
    private let projectTypeNames: Set<String>
    private let containersByName: [String: [SwiftContainer]]
    private var conformanceCache: [String: Set<String>] = [:]

    init(scanner: SwiftDeclarationScanner, isLibraryPackage: Bool) {
        self.scanner = scanner
        self.isLibraryPackage = isLibraryPackage
        containersByName = Dictionary(grouping: scanner.containers, by: \.name)
        projectTypeNames = Set(scanner.containers.filter { $0.kind != .extension }.map(\.name))

        var cache: [String: Set<String>] = [:]
        for name in containersByName.keys {
            cache[name] = Self.expandedConformances(of: name, containersByName: containersByName)
        }
        conformanceCache = cache
    }

    func containers(named name: String) -> [SwiftContainer] {
        containersByName[name] ?? []
    }

    func nonReferenceTokens(inFile fileIndex: Int) -> Set<Int> {
        scanner.nonReferenceTokens[fileIndex] ?? []
    }

    func isRetained(_ declaration: SwiftDeclaration) -> Bool {
        if !declaration.attributes.isDisjoint(with: SwiftRetentionRules.retainingAttributes) { return true }
        if declaration.modifiers.contains("override") || declaration.modifiers.contains("dynamic") { return true }
        if declaration.name == "_" { return true }
        // Synthesized Codable conformance reads `CodingKeys` without naming it.
        if declaration.kind == .enum && declaration.name == "CodingKeys" { return true }

        let isPublicAPI = declaration.modifiers.contains("public")
            || declaration.modifiers.contains("open")
            || declaration.modifiers.contains("package")
        if isLibraryPackage && isPublicAPI { return true }

        if let own = declaration.ownContainerIndex {
            let conformances = conformanceCache[scanner.containers[own].name] ?? []
            if !conformances.isDisjoint(with: SwiftRetentionRules.systemDiscoveredConformances) { return true }
        }

        guard let containerIndex = declaration.containerIndex else { return false }
        let container = scanner.containers[containerIndex]
        if container.attributes.contains("objcMembers") { return true }

        let conformances = conformanceCache[container.name] ?? []

        if declaration.kind == .enumCase {
            return container.name == "CodingKeys"
                || !conformances.isDisjoint(with: SwiftRetentionRules.valueBackedEnumConformances)
        }

        if declaration.kind == .property, !declaration.modifiers.contains("static"), !declaration.modifiers.contains("class"),
           !conformances.isDisjoint(with: SwiftRetentionRules.codableConformances) {
            return true
        }

        // Private members can never witness a protocol requirement.
        if declaration.isFilePrivate { return false }

        if SwiftRetentionRules.implicitMemberNames.contains(declaration.name) { return true }
        if scanner.requirementNames.contains(declaration.name) { return true }

        // Members of types conforming to framework protocols or subclassing framework
        // classes may be called by the framework: only private ones are reported.
        return conformances.contains { name in
            !SwiftRetentionRules.neutralConformances.contains(name) && !projectTypeNames.contains(name)
        }
    }

    /// Conformances of a type across its declaration and extensions, including
    /// everything inherited through project protocols and classes.
    private static func expandedConformances(
        of name: String,
        containersByName: [String: [SwiftContainer]]
    ) -> Set<String> {
        var result: Set<String> = []
        var queue = [name]
        var visited: Set<String> = []

        while let current = queue.popLast() {
            guard visited.insert(current).inserted else { continue }
            for container in containersByName[current] ?? [] {
                for inherited in container.inheritance where !result.contains(inherited) {
                    result.insert(inherited)
                    queue.append(inherited)
                }
            }
        }
        return result
    }
}
