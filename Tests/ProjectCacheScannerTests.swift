// Run from the repository root:
// swiftc -parse-as-library DevAtlasMac/Models/ProjectCache.swift DevAtlasMac/Services/ProjectCacheScanner.swift \
//   Tests/ProjectCacheScannerTests.swift -o /tmp/devatlas-cache-tests && /tmp/devatlas-cache-tests
import Foundation

@main
struct ProjectCacheScannerTests {
    static let fileManager = FileManager.default

    static func main() throws {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("DevAtlas cache tests \(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        try checkJavaScript(in: root)
        try checkSwift(in: root)
        try checkOtherLanguages(in: root)
        try checkNestedProjects(in: root)
        try checkRemoval(in: root)
        print("ProjectCacheScanner: all checks passed (JavaScript, Swift, Flutter, Rust, .NET, Python, PHP, nesting, removal).")
    }

    // MARK: - Checks

    private static func checkJavaScript(in root: URL) throws {
        let project = root.appendingPathComponent("web")
        try write("{}", to: project, "package.json")
        try write("module", to: project, "node_modules/left-pad/index.js")
        try write("chunk", to: project, ".next/cache/chunk.js")
        try write("bundle", to: project, "dist/app.js")
        try write("source", to: project, "build/tool.js")
        try write("dist/\n", to: project, ".gitignore")
        try write("module", to: project, "packages/ui/node_modules/react/index.js")
        try write("{}", to: project, "packages/ui/package.json")
        try git(["init", "-q"], at: project)

        let found = names(ProjectCacheScanner.caches(inProjectAt: project.path))
        try expect(found == ["node_modules": .nodeModules, ".next": .frameworkCache, "dist": .buildOutput,
                             "packages/ui/node_modules": .nodeModules],
                   "JavaScript caches, with the tracked build folder left alone: \(found)")

        // Without a repository there is no proof that dist is generated.
        let plain = root.appendingPathComponent("plain")
        try write("{}", to: plain, "package.json")
        try write("bundle", to: plain, "dist/app.js")
        try expect(ProjectCacheScanner.caches(inProjectAt: plain.path).isEmpty, "dist outside a repository is not offered")
    }

    private static func checkSwift(in root: URL) throws {
        let project = root.appendingPathComponent("swift")
        try write("// swift-tools-version:5.9", to: project, "Package.swift")
        try write("object", to: project, ".build/debug/App.o")
        try write("pod", to: project, "Pods/Alamofire/Source.swift")
        try write("platform :ios", to: project, "Podfile")
        try write("binary", to: project, "Carthage/Build/Lib.framework/Lib")
        try write("source", to: project, "Carthage/Checkouts/Lib/Lib.swift")
        try write("github \"a/b\"", to: project, "Cartfile")
        try write("source", to: project, "Sources/build/Helper.swift")

        var found = names(ProjectCacheScanner.caches(inProjectAt: project.path))
        try expect(found == [".build": .buildOutput, "Carthage/Build": .packages],
                   "Swift caches before Pods is ignored: \(found)")

        try write("Pods/\n", to: project, ".gitignore")
        try git(["init", "-q"], at: project)
        found = names(ProjectCacheScanner.caches(inProjectAt: project.path))
        try expect(found == [".build": .buildOutput, "Carthage/Build": .packages, "Pods": .packages],
                   "Ignored Pods are offered: \(found)")
    }

    private static func checkOtherLanguages(in root: URL) throws {
        let flutter = root.appendingPathComponent("flutter")
        try write("name: app", to: flutter, "pubspec.yaml")
        try write("apk", to: flutter, "build/app.apk")
        try write("config", to: flutter, ".dart_tool/package_config.json")
        try write("lock", to: flutter, "android/.gradle/8.0/file.lock")
        try write("plugins {}", to: flutter, "android/build.gradle")
        try expect(names(ProjectCacheScanner.caches(inProjectAt: flutter.path))
                   == ["build": .buildOutput, ".dart_tool": .toolCache, "android/.gradle": .toolCache], "Flutter")

        let rust = root.appendingPathComponent("rust")
        try write("[package]", to: rust, "Cargo.toml")
        try write("binary", to: rust, "target/debug/app")
        try expect(names(ProjectCacheScanner.caches(inProjectAt: rust.path)) == ["target": .buildOutput], "Rust")

        let dotnet = root.appendingPathComponent("dotnet")
        try write("", to: dotnet, "App.sln")
        try write("<Project/>", to: dotnet, "App/App.csproj")
        try write("dll", to: dotnet, "App/bin/Debug/App.dll")
        try write("cache", to: dotnet, "App/obj/project.assets.json")
        try write("script", to: dotnet, "bin/deploy.sh")
        try expect(names(ProjectCacheScanner.caches(inProjectAt: dotnet.path))
                   == ["App/bin": .buildOutput, "App/obj": .buildOutput], ".NET build folders beside the project file only")

        let python = root.appendingPathComponent("python")
        try write("flask", to: python, "requirements.txt")
        try write("home = /usr/bin", to: python, ".venv/pyvenv.cfg")
        try write("bytecode", to: python, "app/__pycache__/main.pyc")
        try write("settings", to: python, "env/production.toml")
        try expect(names(ProjectCacheScanner.caches(inProjectAt: python.path))
                   == [".venv": .virtualEnv, "app/__pycache__": .toolCache], "Python, with a config folder named env left alone")

        let php = root.appendingPathComponent("php")
        try write("{}", to: php, "composer.json")
        try write("<?php", to: php, "vendor/autoload.php")
        try write("vendor\n", to: php, ".gitignore")
        try git(["init", "-q"], at: php)
        try expect(names(ProjectCacheScanner.caches(inProjectAt: php.path)) == ["vendor": .packages], "PHP")

        let go = root.appendingPathComponent("go")
        try write("module app", to: go, "go.mod")
        try write("package dep", to: go, "vendor/dep/dep.go")
        try expect(ProjectCacheScanner.caches(inProjectAt: go.path).isEmpty, "A Go vendor folder is source, not cache")
    }

    private static func checkNestedProjects(in root: URL) throws {
        let parent = root.appendingPathComponent("mono")
        let child = parent.appendingPathComponent("apps/api")
        try write("{}", to: parent, "package.json")
        try write("module", to: parent, "node_modules/a/index.js")
        try write("{}", to: child, "package.json")
        try write("module", to: child, "node_modules/b/index.js")

        let parentCaches = ProjectCacheScanner.caches(inProjectAt: parent.path, skipping: [child.path])
        try expect(names(parentCaches) == ["node_modules": .nodeModules], "A nested project keeps its own caches")
        try expect(names(ProjectCacheScanner.caches(inProjectAt: child.path)) == ["node_modules": .nodeModules], "Nested project")
        try expect(parentCaches.allSatisfy { $0.size > 0 }, "Sizes are measured")
    }

    private static func checkRemoval(in root: URL) throws {
        let project = root.appendingPathComponent("removal")
        try write("{}", to: project, "package.json")
        try write("module", to: project, "node_modules/a/index.js")
        let link = project.appendingPathComponent("linked")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: project.appendingPathComponent("node_modules"))

        do {
            try ProjectCacheScanner.remove(link.path, toTrash: false)
            throw Failure("Symbolic links must be refused")
        } catch ProjectCacheScanner.RemovalError.notACacheFolder {}
        do {
            try ProjectCacheScanner.remove("/tmp", toTrash: false)
            throw Failure("Shallow paths must be refused")
        } catch ProjectCacheScanner.RemovalError.notACacheFolder {}

        try ProjectCacheScanner.remove(project.appendingPathComponent("node_modules").path, toTrash: false)
        try expect(!fileManager.fileExists(atPath: project.appendingPathComponent("node_modules").path), "Folder removed")
        try expect(fileManager.fileExists(atPath: project.appendingPathComponent("package.json").path), "Project untouched")
    }

    // MARK: - Helpers

    private static func names(_ items: [CacheItem]) -> [String: CacheKind] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.displayName, $0.kind) })
    }

    private static func write(_ text: String, to project: URL, _ relativePath: String) throws {
        let url = project.appendingPathComponent(relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func git(_ arguments: [String], at directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try expect(process.terminationStatus == 0, "git \(arguments.joined(separator: " "))")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(message) }
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
