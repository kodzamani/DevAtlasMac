import Foundation
import AppKit

struct CodeEditor: Identifiable {
    let id: String
    let name: String
    let bundleIdentifiers: [String]
    let appNames: [String]

    static let allKnown: [CodeEditor] = [
        CodeEditor(id: "vscode", name: "VS Code",
                   bundleIdentifiers: ["com.microsoft.VSCode"],
                   appNames: ["Visual Studio Code.app"]),
        CodeEditor(id: "cursor", name: "Cursor",
                   bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"],
                   appNames: ["Cursor.app"]),
        CodeEditor(id: "windsurf", name: "Windsurf",
                   bundleIdentifiers: ["com.exafunction.windsurf"],
                   appNames: ["Windsurf.app"]),
        CodeEditor(id: "antigravity", name: "Antigravity",
                   bundleIdentifiers: ["dev.antigravity.Antigravity"],
                   appNames: ["Antigravity.app"]),
    ]
}
