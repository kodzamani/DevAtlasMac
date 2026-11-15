import Foundation

/// A terminal coding agent DevAtlas knows how to find and launch in a project folder.
struct CodingAgent: Identifiable, Hashable, Sendable {
    /// How an agent accepts a first task while still opening its interactive session.
    enum PromptStyle: Hashable, Sendable {
        /// `agent "task"`
        case positional
        /// `agent <flag> "task"`
        case flag(String)
        /// No known argument: the task is typed into the terminal once the agent is up.
        case typed
    }

    let id: String
    let name: String
    /// Command names to look for, in order of preference.
    let executables: [String]
    /// Install folders the agents' own installers use, which a GUI app's PATH usually lacks.
    let extraSearchPaths: [String]
    let promptStyle: PromptStyle

    func launchArguments(prompt: String?) -> [String] {
        guard let prompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty else { return [] }
        switch promptStyle {
        case .positional: return [prompt]
        case .flag(let flag): return [flag, prompt]
        case .typed: return []
        }
    }

    /// The task to type into the terminal after launch, for agents that take no prompt argument.
    func typedPrompt(_ prompt: String?) -> String? {
        guard promptStyle == .typed,
              let prompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines), !prompt.isEmpty else { return nil }
        return prompt
    }

    static let allKnown: [CodingAgent] = [
        CodingAgent(id: "claude", name: "Claude Code", executables: ["claude"],
                    extraSearchPaths: ["~/.local/bin", "~/.claude/local"], promptStyle: .positional),
        CodingAgent(id: "opencode", name: "OpenCode", executables: ["opencode"],
                    extraSearchPaths: ["~/.opencode/bin"], promptStyle: .flag("--prompt")),
        CodingAgent(id: "antigravity", name: "Antigravity", executables: ["agy", "antigravity"],
                    extraSearchPaths: ["~/.antigravity/antigravity/bin", "~/.gemini/antigravity/bin",
                                       "/Applications/Antigravity.app/Contents/Resources/app/bin"],
                    promptStyle: .typed),
        CodingAgent(id: "codex", name: "Codex", executables: ["codex"],
                    extraSearchPaths: [], promptStyle: .positional),
        CodingAgent(id: "gemini", name: "Gemini CLI", executables: ["gemini"],
                    extraSearchPaths: [], promptStyle: .flag("-i")),
        CodingAgent(id: "qwen", name: "Qwen Code", executables: ["qwen"],
                    extraSearchPaths: [], promptStyle: .flag("-i")),
        CodingAgent(id: "cursor", name: "Cursor Agent", executables: ["cursor-agent"],
                    extraSearchPaths: [], promptStyle: .positional),
        CodingAgent(id: "copilot", name: "GitHub Copilot", executables: ["copilot"],
                    extraSearchPaths: [], promptStyle: .flag("-i")),
        CodingAgent(id: "aider", name: "Aider", executables: ["aider"],
                    extraSearchPaths: [], promptStyle: .typed),
        CodingAgent(id: "amp", name: "Amp", executables: ["amp"],
                    extraSearchPaths: [], promptStyle: .typed),
    ]

    /// Common user-level bin folders shared by npm, bun and pip installs.
    static let sharedSearchPaths = [
        "~/.local/bin", "~/.npm-global/bin", "~/.bun/bin", "~/.cargo/bin", "~/.volta/bin",
        "/opt/homebrew/bin", "/usr/local/bin",
    ]
}

struct DetectedAgent: Identifiable, Hashable, Sendable {
    let agent: CodingAgent
    /// Nil when the agent is not installed.
    let path: String?
    var version: String?

    var id: String { agent.id }
    var isInstalled: Bool { path != nil }
}
