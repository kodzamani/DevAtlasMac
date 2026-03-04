import Foundation
import AppKit

class ProjectRunner {
    
    func isRunnableProject(at path: String) -> Bool {
        getStartCommand(at: path) != nil
    }

    // MARK: - Node Modules Check
    
    func hasNodeModules(at path: String) -> Bool {
        let nodeModulesPath = (path as NSString).appendingPathComponent("node_modules")
        return FileManager.default.fileExists(atPath: nodeModulesPath)
    }
    
    // MARK: - Package.json Scripts
    
    struct PackageScript: Identifiable {
        let id = UUID()
        let name: String
        let command: String
    }
    
    func getAllScripts(at path: String) -> [PackageScript] {
        let packageJsonPath = (path as NSString).appendingPathComponent("package.json")
        
        guard FileManager.default.fileExists(atPath: packageJsonPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: packageJsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: Any]
        else { return [] }
        
        // Get preferred scripts first
        let preferred = ["dev", "start", "serve", "build", "preview"]
        var result: [PackageScript] = []
        
        // Add preferred scripts first (in order)
        for name in preferred {
            if let command = scripts[name] as? String {
                result.append(PackageScript(name: name, command: command))
            }
        }
        
        // Add remaining scripts
        for (name, command) in scripts {
            if !preferred.contains(name) {
                result.append(PackageScript(name: name, command: command as? String ?? ""))
            }
        }
        
        return result
    }

    func getStartCommand(at path: String) -> String? {
        let packageJsonPath = (path as NSString).appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: packageJsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: Any]
        else { return nil }

        let preferred = ["dev", "start", "serve", "build", "preview"]
        for script in preferred {
            if scripts.keys.contains(script) { return script }
        }
        return nil
    }

    // MARK: - Run / Stop

    func runProject(at path: String, command: String? = nil) {
        let cmd = command ?? getStartCommand(at: path) ?? "start"
        let packageManager = detectPackageManager(at: path)
        
        // Check if node_modules exists
        let needsInstall = !hasNodeModules(at: path)
        
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        
        let installAndRunCommand: String
        if needsInstall {
            installAndRunCommand = """
            tell application "Terminal"
                activate
                do script "cd \\"\(escapedPath)\\" && \(packageManager) install && \(packageManager) run \(cmd)"
            end tell
            """
        } else {
            installAndRunCommand = """
            tell application "Terminal"
                activate
                do script "cd \\"\(escapedPath)\\" && \(packageManager) run \(cmd)"
            end tell
            """
        }

        runOsascript(installAndRunCommand)
    }

    // MARK: - Quick Actions

    func openInVSCode(at path: String) {
        let url = URL(fileURLWithPath: path)

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: .init()) { _, _ in }
            return
        }

        let codePaths = ["/usr/local/bin/code", "/opt/homebrew/bin/code"]
        for codePath in codePaths {
            if FileManager.default.fileExists(atPath: codePath) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: codePath)
                process.arguments = [path]
                try? process.run()
                return
            }
        }
    }

    func openInXcode(at path: String) {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        let xcworkspace = (try? fm.contentsOfDirectory(atPath: path))?
            .first { $0.hasSuffix(".xcworkspace") }
        let xcodeproj = (try? fm.contentsOfDirectory(atPath: path))?
            .first { $0.hasSuffix(".xcodeproj") }
        let packageSwift = url.appendingPathComponent("Package.swift")

        let target: String
        if let ws = xcworkspace {
            target = url.appendingPathComponent(ws).path
        } else if let proj = xcodeproj {
            target = url.appendingPathComponent(proj).path
        } else if fm.fileExists(atPath: packageSwift.path) {
            target = packageSwift.path
        } else {
            target = path
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", "com.apple.dt.Xcode", target]
        try? process.run()
    }

    func openTerminal(at path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", path]
        try? process.run()
    }

    func revealInFinder(at path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    // MARK: - Code Editor Detection

    func installedEditors() -> [CodeEditor] {
        CodeEditor.allKnown.filter { resolveAppURL(for: $0) != nil }
    }

    func openInEditor(_ editor: CodeEditor, at path: String) {
        guard let appURL = resolveAppURL(for: editor) else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: .init()) { _, _ in }
    }

    func editorIcon(for editor: CodeEditor) -> NSImage {
        if let appURL = resolveAppURL(for: editor) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
    }

    private func resolveAppURL(for editor: CodeEditor) -> URL? {
        for bundleId in editor.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return url
            }
        }
        for appName in editor.appNames {
            let path = "/Applications/\(appName)"
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    // MARK: - AppleScript Helper

    private func runOsascript(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    // MARK: - Helpers

    private func detectPackageManager(at path: String) -> String {
        let yarnLock = (path as NSString).appendingPathComponent("yarn.lock")
        let pnpmLock = (path as NSString).appendingPathComponent("pnpm-lock.yaml")

        if FileManager.default.fileExists(atPath: pnpmLock) { return "pnpm" }
        if FileManager.default.fileExists(atPath: yarnLock) { return "yarn" }
        return "npm"
    }
}
