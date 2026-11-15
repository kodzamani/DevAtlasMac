import AppKit
import Foundation
import Observation
import SwiftTerm

/// Terminal sessions for coding agents. Lives on `AppViewModel`, so agents keep running while the
/// user is on another tab or the window is closed to the menu bar.
@MainActor
@Observable
final class AgentSessionsViewModel {
    nonisolated init() {}

    private(set) var agents: [DetectedAgent] = []
    private(set) var isDetecting = false
    private(set) var hasDetected = false
    private(set) var sessions: [AgentSession] = []
    var selectedSessionID: UUID?
    /// The agent last started, preselected in the launcher.
    var preferredAgentID: String? = UserDefaults.standard.string(forKey: "agents.preferredAgent") {
        didSet { UserDefaults.standard.set(preferredAgentID, forKey: "agents.preferredAgent") }
    }

    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    var installedAgents: [DetectedAgent] { agents.filter(\.isInstalled) }
    var selectedSession: AgentSession? { sessions.first { $0.id == selectedSessionID } }

    func ensureDetected() async {
        guard !hasDetected else { return }
        await refreshAgents()
    }

    func refreshAgents() async {
        guard !isDetecting else { return }
        isDetecting = true
        defer { isDetecting = false }
        agents = await Task.detached(priority: .userInitiated) { await AgentDetector.detect() }.value
        hasDetected = true
    }

    @discardableResult
    func start(_ agent: DetectedAgent, projectName: String, directory: String, prompt: String?) -> AgentSession? {
        guard agent.isInstalled else { return nil }
        preferredAgentID = agent.id
        return open(AgentSession(launch: .agent(agent), projectName: projectName, directory: directory, prompt: prompt))
    }

    @discardableResult
    func startShell(projectName: String, directory: String) -> AgentSession {
        open(AgentSession(launch: .shell, projectName: projectName, directory: directory, prompt: nil))
    }

    func restart(_ session: AgentSession) {
        session.restart()
    }

    func close(_ session: AgentSession) {
        session.terminate()
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions.remove(at: index)
        if selectedSessionID == session.id {
            selectedSessionID = sessions.indices.contains(index) ? sessions[index].id : sessions.last?.id
        }
    }

    func terminateAll() {
        sessions.forEach { $0.terminate() }
    }

    private func open(_ session: AgentSession) -> AgentSession {
        observeTerminationIfNeeded()
        sessions.append(session)
        selectedSessionID = session.id
        session.start()
        return session
    }

    private func observeTerminationIfNeeded() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.terminateAll() }
        }
    }
}

/// One agent (or shell) running in a pseudo-terminal in a project folder.
@MainActor
@Observable
final class AgentSession: Identifiable {
    enum Launch {
        case agent(DetectedAgent)
        case shell
    }
    enum State: Equatable {
        case running
        case exited(Int32?)
    }

    let id = UUID()
    let launch: Launch
    let projectName: String
    let directory: String
    let prompt: String?
    private(set) var state: State = .running
    /// Set by the program through the terminal title escape sequence.
    private(set) var terminalTitle: String?
    /// Replaced on restart so the new run starts with a clean screen.
    private(set) var terminalView: AgentTerminalNSView

    @ObservationIgnored private var bridge: Bridge?
    @ObservationIgnored private var typedPromptTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTypedPrompt: String?

    init(launch: Launch, projectName: String, directory: String, prompt: String?) {
        self.launch = launch
        self.projectName = projectName
        self.directory = directory
        self.prompt = prompt
        self.terminalView = AgentTerminalNSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
    }

    var title: String {
        switch launch {
        case .agent(let agent): return agent.agent.name
        case .shell: return "agents.shell".localized
        }
    }

    var agentID: String? {
        if case .agent(let agent) = launch { return agent.id }
        return nil
    }

    var isRunning: Bool { state == .running }

    func start() {
        let view = terminalView
        let bridge = Bridge(session: self)
        self.bridge = bridge
        view.processDelegate = bridge
        view.onOutput = { [weak self] in MainActor.assumeIsolated { self?.outputArrived() } }
        state = .running

        let environment = Self.environment()
        let workingDirectory = FileManager.default.fileExists(atPath: directory) ? directory : NSHomeDirectory()
        switch launch {
        case .agent(let agent):
            guard let path = agent.path else { return }
            pendingTypedPrompt = agent.agent.typedPrompt(prompt)
            view.startProcess(executable: path, args: agent.agent.launchArguments(prompt: prompt),
                              environment: environment, currentDirectory: workingDirectory)
        case .shell:
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            // A leading dash in argv[0] makes it a login shell, as Terminal.app does.
            view.startProcess(executable: shell, args: [], environment: environment,
                              execName: "-" + (shell as NSString).lastPathComponent, currentDirectory: workingDirectory)
        }
    }

    func restart() {
        terminate()
        let fresh = AgentTerminalNSView(frame: terminalView.frame)
        fresh.applyTheme(dark: terminalView.isDarkTheme)
        terminalView = fresh
        terminalTitle = nil
        start()
    }

    func terminate() {
        typedPromptTask?.cancel()
        if state == .running {
            terminalView.terminate()
        }
    }

    fileprivate func processTerminated(exitCode: Int32?) {
        typedPromptTask?.cancel()
        state = .exited(exitCode)
    }

    fileprivate func titleChanged(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        terminalTitle = trimmed.isEmpty ? nil : trimmed
    }

    /// Types the first task once the agent's screen has settled, for agents with no prompt argument.
    private func outputArrived() {
        guard pendingTypedPrompt != nil else { return }
        typedPromptTask?.cancel()
        typedPromptTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self, let prompt = self.pendingTypedPrompt, self.state == .running else { return }
            self.pendingTypedPrompt = nil
            self.terminalView.send(txt: prompt)
            try? await Task.sleep(for: .milliseconds(120))
            self.terminalView.send(txt: "\r")
        }
    }

    /// The login shell's environment, minus values that belong to whatever launched DevAtlas.
    static func environment() -> [String] {
        var env = AgentDetector.loginShellEnvironment()
        let droppedPrefixes = ["DYLD_", "__XPC_", "XPC_", "OS_ACTIVITY_", "__CF", "CLAUDECODE", "CLAUDE_CODE_"]
        for key in env.keys where droppedPrefixes.contains(where: key.hasPrefix) || key == "NSUnbufferedIO" {
            env.removeValue(forKey: key)
        }
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["TERM_PROGRAM"] = "DevAtlas"
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        return env.map { "\($0.key)=\($0.value)" }
    }

    /// SwiftTerm's delegate is a class protocol; this keeps the session free of NSObject.
    /// Only touches the session on the main queue.
    private final class Bridge: LocalProcessTerminalViewDelegate, @unchecked Sendable {
        weak var session: AgentSession?
        init(session: AgentSession) { self.session = session }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            MainActor.assumeIsolated { session?.titleChanged(title) }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // SwiftTerm reports this from its process queue.
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.session?.processTerminated(exitCode: exitCode) }
            }
        }
    }
}

/// The terminal view with DevAtlas's font and colors, and a hook for incoming output.
final class AgentTerminalNSView: LocalProcessTerminalView {
    var onOutput: (() -> Void)?
    private(set) var isDarkTheme = true

    override init(frame: NSRect) {
        super.init(frame: frame)
        font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        optionAsMetaKey = true
        applyTheme(dark: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private var hasAppliedTheme = false

    func applyTheme(dark: Bool) {
        if hasAppliedTheme, dark == isDarkTheme { return }
        hasAppliedTheme = true
        isDarkTheme = dark
        if dark {
            nativeBackgroundColor = NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1)
            nativeForegroundColor = NSColor(srgbRed: 0.90, green: 0.90, blue: 0.92, alpha: 1)
            caretColor = NSColor(srgbRed: 0.75, green: 0.75, blue: 0.80, alpha: 1)
            selectedTextBackgroundColor = NSColor(srgbRed: 0.25, green: 0.32, blue: 0.48, alpha: 1)
        } else {
            nativeBackgroundColor = NSColor(srgbRed: 0.985, green: 0.985, blue: 0.99, alpha: 1)
            nativeForegroundColor = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            caretColor = NSColor(srgbRed: 0.30, green: 0.30, blue: 0.35, alpha: 1)
            selectedTextBackgroundColor = NSColor(srgbRed: 0.72, green: 0.80, blue: 0.95, alpha: 1)
        }
        needsDisplay = true
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onOutput?()
    }
}
