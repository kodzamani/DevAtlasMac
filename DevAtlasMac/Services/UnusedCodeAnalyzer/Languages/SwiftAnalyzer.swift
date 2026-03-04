import Foundation

// MARK: - Swift Analyzer

class SwiftAnalyzer: LanguageAnalyzer {
    let languageName = "Swift"

    private let peripheryCandidatePaths = [
        "/opt/homebrew/bin/periphery",
        "/usr/local/bin/periphery",
        "/usr/bin/periphery"
    ]

    func analyze(projectPath: String) throws -> [UnusedCodeResult] {
        try runPeriphery(at: projectPath)
    }

    private func runPeriphery(at path: String) throws -> [UnusedCodeResult] {
        guard let executableURL = resolvePeripheryExecutable() else {
            throw AnalyzerError.peripheryNotFound
        }

        let fileManager = FileManager.default
        let contents = try? fileManager.contentsOfDirectory(atPath: path)
        guard let projectFile = resolveProjectFile(from: contents ?? []) else {
            throw AnalyzerError.executionFailed("No .xcodeproj or .xcworkspace found for Periphery scan")
        }

        let scheme = try resolvePrimaryScheme(at: path, projectFile: projectFile)

        let process = Process()
        process.executableURL = executableURL

        var arguments = [
            "scan",
            "--project", projectFile,
            "--schemes", scheme,
            "--format", "json"
        ]

        arguments.append("--disable-update-check")

        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            throw AnalyzerError.executionFailed(errorMessage?.isEmpty == false ? errorMessage! : "Periphery failed")
        }

        guard let jsonArray = try JSONSerialization.jsonObject(with: outputData) as? [[String: Any]] else {
            throw AnalyzerError.parsingFailed
        }

        return jsonArray.compactMap { dict in
            guard let kind = dict["kind"] as? String,
                  let name = dict["name"] as? String,
                  let location = dict["location"] as? String else {
                return nil
            }

            let hints = dict["hints"] as? [String] ?? []
            return UnusedCodeResult(
                kind: kind,
                name: name,
                location: formatDisplayLocation(location),
                hints: hints
            )
        }
    }

    private func resolveProjectFile(from contents: [String]) -> String? {
        if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
            return workspace
        }

        return contents.first(where: { $0.hasSuffix(".xcodeproj") })
    }

    private func resolvePrimaryScheme(at path: String, projectFile: String) throws -> String {
        let discoveredSchemes = try discoverSchemes(at: path, projectFile: projectFile)
        let containerName = URL(fileURLWithPath: projectFile).deletingPathExtension().lastPathComponent

        if let exactMatch = discoveredSchemes.first(where: { $0 == containerName }) {
            return exactMatch
        }

        if let targetMatch = discoveredSchemes.first(where: { $0.caseInsensitiveCompare(containerName) == .orderedSame }) {
            return targetMatch
        }

        guard let firstScheme = discoveredSchemes.first else {
            throw AnalyzerError.executionFailed("No shared schemes found for Periphery scan")
        }

        return firstScheme
    }

    private func discoverSchemes(at path: String, projectFile: String) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")

        let isWorkspace = projectFile.hasSuffix(".xcworkspace")
        process.arguments = [
            "-list",
            "-json",
            isWorkspace ? "-workspace" : "-project",
            projectFile
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            throw AnalyzerError.executionFailed(errorMessage?.isEmpty == false ? errorMessage! : "Failed to discover Xcode schemes")
        }

        guard let jsonObject = try JSONSerialization.jsonObject(with: outputData) as? [String: Any] else {
            throw AnalyzerError.parsingFailed
        }

        let containerKey = isWorkspace ? "workspace" : "project"
        let container = jsonObject[containerKey] as? [String: Any]
        let schemes = container?["schemes"] as? [String] ?? []

        return schemes.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func formatDisplayLocation(_ rawLocation: String) -> String {
        let components = rawLocation.split(separator: ":", omittingEmptySubsequences: false)

        guard let rawPath = components.first, !rawPath.isEmpty else {
            return rawLocation
        }

        let fileName = URL(fileURLWithPath: String(rawPath)).lastPathComponent
        let suffix = components.dropFirst().joined(separator: ":")

        guard !suffix.isEmpty else {
            return fileName
        }

        return "\(fileName):\(suffix)"
    }

    private func resolvePeripheryExecutable() -> URL? {
        let fileManager = FileManager.default

        if let installedPath = peripheryCandidatePaths.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: installedPath)
        }

        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        for directory in pathDirectories {
            let candidatePath = (directory as NSString).appendingPathComponent("periphery")
            if fileManager.isExecutableFile(atPath: candidatePath) {
                return URL(fileURLWithPath: candidatePath)
            }
        }

        return nil
    }
}
