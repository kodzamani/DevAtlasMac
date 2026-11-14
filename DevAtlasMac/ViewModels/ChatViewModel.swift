import SwiftUI
import AppKit
import Observation

/// State behind the Chat tab: a conversational command interface over the user's projects.
/// Nothing here talks to a language model; typed text is matched against projects, actions and
/// slash commands, and the answers come from ChatActionExecutor.
@MainActor
@Observable
final class ChatViewModel {
    @ObservationIgnored let appViewModel: AppViewModel
    @ObservationIgnored private let executor: ChatActionExecutor
    @ObservationIgnored private let store = ChatStore.shared

    private struct RunningTask {
        let conversationID: String
        let task: Task<Void, Never>
    }

    @ObservationIgnored private var tasks: [String: RunningTask] = [:]
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var actionCache: [String: [ChatAction]] = [:]

    static let suggestionLimit = 6
    static let projectListLimit = 8
    private static let thinkingDelay = Duration.milliseconds(300)
    private static let animation = Animation.snappy(duration: 0.25)

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        self.executor = ChatActionExecutor(appViewModel: appViewModel)
    }

    // MARK: Conversations

    private(set) var conversations: [ChatConversation] = []
    private(set) var current = ChatConversation()
    var messages: [ChatMessage] { current.messages }

    var activeProject: ProjectInfo? {
        guard let id = current.activeProjectID else { return nil }
        return resolveProject(id: id, in: current)
    }

    func load() async {
        if hasLoaded { return }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            let loaded = await self.store.loadConversations()
            self.apply(loaded: loaded)
        }
        loadTask = task
        await task.value
        hasLoaded = true
    }

    private func apply(loaded: [ChatConversation]) {
        if current.messages.isEmpty {
            // Anything typed before the load finished lives in `current`; otherwise resume the newest thread.
            conversations = loaded
            current = loaded.first ?? ChatConversation()
        } else {
            conversations = ChatStore.trimmed(loaded.filter { $0.id != current.id } + [current])
        }
    }

    func newConversation() {
        pendingInput = nil
        draft = ""
        if !current.messages.isEmpty {
            withAnimation(Self.animation) {
                current = ChatConversation()
            }
        }
        focusRequest += 1
    }

    func selectConversation(_ id: String) {
        guard id != current.id, let conversation = conversations.first(where: { $0.id == id }) else { return }
        pendingInput = nil
        draft = ""
        current = conversation
        focusRequest += 1
    }

    func deleteConversation(_ id: String) {
        for (messageID, running) in tasks where running.conversationID == id {
            running.task.cancel()
            tasks[messageID] = nil
        }

        let index = conversations.firstIndex { $0.id == id }
        withAnimation(Self.animation) {
            conversations.removeAll { $0.id == id }
            if current.id == id {
                pendingInput = nil
                draft = ""
                if let index, !conversations.isEmpty {
                    current = conversations[min(index, conversations.count - 1)]
                } else {
                    current = ChatConversation()
                }
            }
        }
        scheduleSave()
    }

    // MARK: Composer

    var draft: String = "" {
        didSet {
            if draft != oldValue { recomputeSuggestions() }
        }
    }
    private(set) var suggestions: [ChatSuggestion] = []
    var suggestionIndex: Int = 0
    private var areSuggestionsDismissed = false
    var isSuggestionListVisible: Bool { !suggestions.isEmpty && !areSuggestionsDismissed }
    private(set) var pendingInput: ChatPendingInput?
    private(set) var focusRequest: Int = 0

    var composerPlaceholder: String {
        switch pendingInput {
        case .noteText: return "chat.composer.notePlaceholder".localized
        case .todoText: return "chat.composer.todoPlaceholder".localized
        case nil:
            if let project = activeProject { return "chat.composer.projectPlaceholder".localized(project.name) }
            return "chat.composer.placeholder".localized
        }
    }

    var isBusy: Bool {
        current.messages.contains { if case .running = $0.status { return true } else { return false } }
    }

    func moveSuggestion(by offset: Int) {
        guard !suggestions.isEmpty else { return }
        if areSuggestionsDismissed {
            areSuggestionsDismissed = false
            return
        }
        let count = suggestions.count
        suggestionIndex = ((suggestionIndex + offset) % count + count) % count
    }

    func dismissSuggestions() {
        areSuggestionsDismissed = true
    }

    @discardableResult
    func acceptSuggestion() -> Bool {
        guard isSuggestionListVisible, suggestions.indices.contains(suggestionIndex) else { return false }
        accept(suggestions[suggestionIndex])
        return true
    }

    func accept(_ suggestion: ChatSuggestion) {
        clearDraft()
        switch suggestion {
        case .project(let project, _):
            selectProject(project)
        case .action(let action, _):
            guard let project = activeProject else { return }
            runAction(action, project: project, echo: action.title)
        case .command(let command):
            run(command)
        }
    }

    func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Return picks the highlighted row, like Tab.
        if acceptSuggestion() { return }

        clearDraft()

        if let pending = pendingInput {
            consumePendingInput(pending, text: text)
            return
        }

        if text.hasPrefix("/") {
            submitCommand(text)
            return
        }

        appendUserMessage(text)

        if let project = activeProject, handleActionText(text, project: project) {
            return
        }
        handleProjectText(text)
    }

    @discardableResult
    func handleEscape() -> Bool {
        if isSuggestionListVisible {
            dismissSuggestions()
            return true
        }
        if pendingInput != nil {
            pendingInput = nil
            recomputeSuggestions()
            return true
        }
        if !draft.isEmpty {
            draft = ""
            return true
        }
        return false
    }

    func stop() {
        for message in current.messages {
            guard case .running = message.status, let running = tasks[message.id] else { continue }
            running.task.cancel()
            tasks[message.id] = nil
            let notice = ChatNotice(kind: .info, title: "chat.notice.stopped".localized)
            updateMessage(message.id, in: current.id) { message in
                message.status = .failed
                message.blocks = [ChatBlock(content: .notice(notice))]
                message.plainText = notice.title
            }
        }
        focusRequest += 1
    }

    // MARK: Thread interactions

    func selectProject(_ project: ProjectInfo) {
        selectProject(project, echo: true)
    }

    func perform(_ action: ChatAction, in message: ChatMessage) {
        guard let project = project(for: message) else {
            appendNotice(.warning, "chat.notice.projectGone".localized)
            return
        }
        runAction(action, project: project, echo: action.title)
    }

    func runScript(_ script: ChatScript, in message: ChatMessage) {
        guard let project = project(for: message) else {
            appendNotice(.warning, "chat.notice.projectGone".localized)
            return
        }
        runAction(.run(script: script.name), project: project, echo: "chat.action.runScript".localized(script.name))
    }

    func resolveConfirmation(blockID: String, in messageID: String, confirmed: Bool) {
        guard let message = current.messages.first(where: { $0.id == messageID }),
              let blockIndex = message.blocks.firstIndex(where: { $0.id == blockID }),
              case .confirm(var confirmation) = message.blocks[blockIndex].content,
              confirmation.state == .pending else { return }

        confirmation.state = confirmed ? .confirmed : .cancelled
        updateMessage(messageID, in: current.id) { message in
            guard message.blocks.indices.contains(blockIndex) else { return }
            message.blocks[blockIndex].content = .confirm(confirmation)
        }

        guard confirmed else {
            focusRequest += 1
            return
        }
        guard let project = project(for: message) else {
            appendNotice(.warning, "chat.notice.projectGone".localized)
            return
        }
        runAction(confirmation.action, project: project, echo: nil)
    }

    func run(_ command: ChatSlashCommand) {
        runCommand(command, echo: true)
    }

    func copy(_ message: ChatMessage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.plainText, forType: .string)
    }

    func availableActions(for project: ProjectInfo) -> [ChatAction] {
        if let cached = actionCache[project.path] { return cached }
        let actions = executor.availableActions(for: project)
        actionCache[project.path] = actions
        return actions
    }

    func project(for message: ChatMessage) -> ProjectInfo? {
        guard let id = message.projectID else { return nil }
        if let project = appViewModel.projects.first(where: { $0.id == id }) { return project }
        let snapshot = message.blocks.lazy.compactMap { block -> ProjectInfo? in
            if case .project(let project) = block.content { return project }
            return nil
        }.first ?? projectSnapshot(id: id, in: current)
        guard let snapshot else { return nil }
        return appViewModel.projects.first { $0.path == snapshot.path } ?? snapshot
    }

    var recentProjects: [ProjectInfo] { Array(appViewModel.menuProjects.prefix(ChatActionExecutor.recentProjectLimit)) }

    // MARK: - Project resolution

    /// Project ids change when the drives are rescanned, so fall back to the path of the snapshot
    /// stored in the conversation's project card.
    private func resolveProject(id: String, in conversation: ChatConversation) -> ProjectInfo? {
        if let project = appViewModel.projects.first(where: { $0.id == id }) { return project }
        guard let snapshot = projectSnapshot(id: id, in: conversation) else { return nil }
        return appViewModel.projects.first { $0.path == snapshot.path } ?? snapshot
    }

    private func projectSnapshot(id: String, in conversation: ChatConversation) -> ProjectInfo? {
        for message in conversation.messages.reversed() where message.projectID == id {
            for block in message.blocks {
                if case .project(let project) = block.content { return project }
            }
        }
        return nil
    }

    // MARK: - Matching

    private struct ProjectMatch {
        let project: ProjectInfo
        let score: Int
        let indices: Set<Int>
    }

    private func matchProjects(_ text: String) -> [ProjectMatch] {
        let needle = text.lowercased()
        var found: [ProjectMatch] = []
        for project in appViewModel.menuProjects {
            if let match = QuickSearchModel.match(text, in: project.name) {
                found.append(ProjectMatch(project: project, score: match.score, indices: match.indices))
            } else if ([project.path, project.projectType] + project.tags).contains(where: { $0.lowercased().contains(needle) }) {
                found.append(ProjectMatch(project: project, score: 50, indices: []))
            }
        }
        // Stable: newest first among equal scores.
        return found.enumerated()
            .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
            .map(\.element)
    }

    /// Actions matching `text`, best first, with their 1-based number in the action list.
    private func matchActions(_ text: String, in actions: [ChatAction]) -> [(action: ChatAction, number: Int)] {
        let lower = text.lowercased()
        let number = Int(lower)
        var scored: [(action: ChatAction, number: Int, score: Int)] = []
        for (index, action) in actions.enumerated() {
            var score = 0
            if number == index + 1 { score = 2_000 }
            if action.keywords.contains(lower) { score = max(score, 1_500) }
            if action.keywords.contains(where: { $0.hasPrefix(lower) }) { score = max(score, 1_000) }
            if let match = QuickSearchModel.match(text, in: action.title), match.score >= 400 {
                score = max(score, match.score)
            }
            if score > 0 { scored.append((action, index + 1, score)) }
        }
        return scored.enumerated()
            .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
            .map { ($0.element.action, $0.element.number) }
    }

    private func recomputeSuggestions() {
        suggestionIndex = 0
        areSuggestionsDismissed = false

        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, pendingInput == nil else {
            if !suggestions.isEmpty { suggestions = [] }
            return
        }

        if text.hasPrefix("/") {
            let query = String(text.dropFirst()).lowercased()
            suggestions = ChatSlashCommand.allCases
                .filter { query.isEmpty || $0.rawValue.hasPrefix(query) || QuickSearchModel.match(query, in: $0.rawValue) != nil }
                .prefix(Self.suggestionLimit)
                .map { .command($0) }
            return
        }

        var result: [ChatSuggestion] = []
        if let project = activeProject {
            result += matchActions(text, in: availableActions(for: project))
                .map { .action($0.action, number: $0.number) }
        }
        if result.count < Self.suggestionLimit {
            result += matchProjects(text)
                .prefix(Self.suggestionLimit - result.count)
                .map { .project($0.project, matchedIndices: $0.indices) }
        }
        suggestions = Array(result.prefix(Self.suggestionLimit))
    }

    // MARK: - Submit handling

    private func submitCommand(_ text: String) {
        let token = text.dropFirst()
            .split(whereSeparator: \.isWhitespace).first
            .map { $0.lowercased() } ?? ""
        let command = token.isEmpty ? nil : ChatSlashCommand.allCases.first { $0.rawValue.hasPrefix(token) }

        if command == .new {
            newConversation()
            return
        }

        appendUserMessage(text)
        guard let command else {
            let list = ChatSlashCommand.allCases.map { "\($0.token) — \($0.title)" }.joined(separator: "\n")
            appendNotice(.info, "chat.notice.unknownCommand".localized(text), detail: list)
            return
        }
        runCommand(command, echo: false)
    }

    /// Returns true when the text picked an action for the active project.
    private func handleActionText(_ text: String, project: ProjectInfo) -> Bool {
        let actions = availableActions(for: project)
        let lower = text.lowercased()

        if let number = Int(lower), (1...max(actions.count, 1)).contains(number), actions.indices.contains(number - 1) {
            runAction(actions[number - 1], project: project, echo: nil)
            return true
        }

        let keywordActions = actions + ChatActionExecutor.keywordOnlyActions
        if let exact = keywordActions.first(where: { $0.keywords.contains(lower) }) {
            runAction(exact, project: project, echo: nil)
            return true
        }

        // A project whose name starts with the text wins over a loose action title match.
        if let other = matchProjects(text).first, other.score >= 900 {
            selectProject(other.project, echo: false)
            return true
        }

        let fuzzy = actions
            .compactMap { action in QuickSearchModel.match(text, in: action.title).map { (action: action, score: $0.score) } }
            .filter { $0.score >= 600 }
            .max { $0.score < $1.score }
        if let fuzzy {
            runAction(fuzzy.action, project: project, echo: nil)
            return true
        }
        return false
    }

    private func handleProjectText(_ text: String) {
        let matches = matchProjects(text)
        let lower = text.lowercased()

        if let exact = matches.first(where: { $0.project.name.lowercased() == lower }) {
            selectProject(exact.project, echo: false)
            return
        }

        guard let top = matches.first else {
            let hasProject = activeProject != nil
            let title = (hasProject ? "chat.notice.noMatchWithProject" : "chat.notice.noProjectMatch").localized(text)
            let notice = ChatNotice(kind: .warning, title: title, detail: "chat.notice.noProjectMatch.detail".localized)
            var blocks = [ChatBlock(content: .notice(notice))]
            let recent = recentProjects
            let listTitle = "chat.card.recent.title".localized
            if !recent.isEmpty {
                blocks.append(ChatBlock(content: .projectList(title: listTitle, projects: recent)))
            }
            appendAssistant(ChatMessage(
                role: .assistant,
                blocks: blocks,
                plainText: title + (recent.isEmpty ? "" : "\n" + ChatActionExecutor.plainList(title: listTitle, projects: recent))
            ))
            return
        }

        let second = matches.dropFirst().first
        let isClearlyAhead = second.map { top.score >= 800 && top.score - $0.score >= 100 } ?? true
        if isClearlyAhead {
            selectProject(top.project, echo: false)
            return
        }

        let projects = matches.prefix(Self.projectListLimit).map(\.project)
        let title = "chat.card.projectList.matches".localized(matches.count)
        appendAssistant(ChatMessage(
            role: .assistant,
            blocks: [ChatBlock(content: .projectList(title: title, projects: Array(projects)))],
            plainText: ChatActionExecutor.plainList(title: title, projects: Array(projects))
        ))
    }

    private func consumePendingInput(_ pending: ChatPendingInput, text: String) {
        pendingInput = nil
        appendUserMessage(text)

        let projectID: String
        let isTodo: Bool
        switch pending {
        case .noteText(let id): projectID = id; isTodo = false
        case .todoText(let id): projectID = id; isTodo = true
        }
        guard let project = resolveProject(id: projectID, in: current) else {
            appendNotice(.warning, "chat.notice.projectGone".localized)
            return
        }

        let conversationID = current.id
        let executor = executor
        Task { [weak self] in
            let noteID = isTodo
                ? await executor.saveTodo(text: text, project: project)
                : await executor.saveNote(text: text, project: project)
            guard let self else { return }
            let title = (isTodo ? "chat.notice.todoSaved" : "chat.notice.noteSaved").localized(project.name)
            let notice = ChatNotice(kind: .success, title: title, detail: text)
            self.appendAssistant(ChatMessage(
                role: .assistant,
                projectID: project.id,
                blocks: [ChatBlock(content: .notice(notice)), ChatBlock(content: .actions([.openNote(id: noteID)]))],
                plainText: title + "\n" + text
            ), to: conversationID)
        }
    }

    // MARK: - Running

    private func selectProject(_ project: ProjectInfo, echo: Bool) {
        let full = appViewModel.projects.first { $0.id == project.id }
            ?? appViewModel.projects.first { $0.path == project.path }
            ?? project
        actionCache[full.path] = nil
        let actions = availableActions(for: full)
        if echo { appendUserMessage(full.name) }

        var lines = ["\(full.name) — \(full.projectType)", full.path]
        lines += actions.enumerated().map { "\($0.offset + 1). \($0.element.title)" }

        modifyConversation(current.id) { conversation in
            conversation.activeProjectID = full.id
            conversation.messages.append(ChatMessage(
                role: .assistant,
                projectID: full.id,
                blocks: [ChatBlock(content: .project(full)), ChatBlock(content: .actions(actions))],
                plainText: lines.joined(separator: "\n")
            ))
            if conversation.title.isEmpty { conversation.title = full.name }
        }
        focusRequest += 1
    }

    private func runAction(_ action: ChatAction, project: ProjectInfo, echo: String?) {
        if let echo { appendUserMessage(echo) }
        let conversationID = current.id

        if current.activeProjectID != project.id {
            modifyConversation(conversationID) { $0.activeProjectID = project.id }
        }

        switch action {
        case .addNote, .addTodo:
            let isTodo = action == .addTodo
            pendingInput = isTodo ? .todoText(projectID: project.id) : .noteText(projectID: project.id)
            recomputeSuggestions()
            let prompt = (isTodo ? "chat.prompt.todo" : "chat.prompt.note").localized(project.name)
            appendAssistant(ChatMessage(
                role: .assistant,
                projectID: project.id,
                blocks: [ChatBlock(content: .text(prompt))],
                plainText: prompt
            ))
            focusRequest += 1
            return
        default:
            break
        }

        let executor = executor
        if action.isInstant {
            Task { [weak self] in
                let result = await executor.execute(action, project: project)
                self?.appendAssistant(Self.message(for: result, projectID: project.id), to: conversationID)
            }
            focusRequest += 1
            return
        }

        let placeholder = ChatMessage(
            role: .assistant,
            projectID: project.id,
            blocks: [],
            status: .running(label: Self.runningLabel(for: action))
        )
        appendAssistant(placeholder)
        let messageID = placeholder.id

        let task = Task { [weak self] in
            let result = await executor.execute(action, project: project)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            self.tasks[messageID] = nil
            let finished = Self.message(for: result, projectID: project.id)
            self.updateMessage(messageID, in: conversationID) { message in
                message.blocks = finished.blocks
                message.plainText = finished.plainText
                message.status = .done
                message.date = Date()
            }
        }
        tasks[messageID] = RunningTask(conversationID: conversationID, task: task)
        focusRequest += 1
    }

    private func runCommand(_ command: ChatSlashCommand, echo: Bool) {
        if command == .new {
            newConversation()
            return
        }
        if echo { appendUserMessage(command.token) }
        let conversationID = current.id
        if current.title.isEmpty {
            modifyConversation(conversationID, animated: false) { $0.title = command.title }
        }

        if command == .rescan {
            startRescan(in: conversationID)
            return
        }

        let executor = executor
        Task { [weak self] in
            let result = await executor.execute(command)
            self?.appendAssistant(ChatMessage(role: .assistant, blocks: result.blocks, plainText: result.plainText),
                                  to: conversationID)
        }
        focusRequest += 1
    }

    private func startRescan(in conversationID: String) {
        guard !appViewModel.scanProgress.isScanning else {
            appendNotice(.info, "chat.notice.alreadyScanning".localized)
            return
        }

        let placeholder = ChatMessage(role: .assistant, blocks: [], status: .running(label: "chat.running.rescan".localized))
        appendAssistant(placeholder, to: conversationID)
        let messageID = placeholder.id
        let executor = executor

        let task = Task { [weak self] in
            let count = await executor.rescan()
            guard let self else { return }
            self.actionCache = [:]
            guard !Task.isCancelled else { return }
            self.tasks[messageID] = nil
            let notice = ChatNotice(kind: .success, title: "chat.notice.rescanDone".localized(count))
            self.updateMessage(messageID, in: conversationID) { message in
                message.blocks = [ChatBlock(content: .notice(notice))]
                message.plainText = notice.title
                message.status = .done
                message.date = Date()
            }
        }
        tasks[messageID] = RunningTask(conversationID: conversationID, task: task)
        focusRequest += 1
    }

    private static func message(for result: ChatActionExecutor.ActionResult, projectID: String) -> ChatMessage {
        var blocks = result.blocks
        if !result.followUps.isEmpty {
            blocks.append(ChatBlock(content: .actions(result.followUps)))
        }
        return ChatMessage(role: .assistant, projectID: projectID, blocks: blocks, plainText: result.plainText)
    }

    private static func runningLabel(for action: ChatAction) -> String {
        let base = action.id.split(separator: ":").first.map(String.init) ?? action.id
        let key = "chat.running.\(base)"
        let value = key.localized
        return value == key || value.isEmpty ? "chat.running.default".localized : value
    }

    // MARK: - Mutations

    private func clearDraft() {
        draft = ""
        suggestions = []
        suggestionIndex = 0
        focusRequest += 1
    }

    private func appendUserMessage(_ text: String) {
        modifyConversation(current.id) { conversation in
            conversation.messages.append(ChatMessage(role: .user, blocks: [ChatBlock(content: .text(text))], plainText: text))
            if conversation.title.isEmpty, !text.hasPrefix("/") {
                conversation.title = text.count > 60 ? String(text.prefix(60)) + "…" : text
            }
        }
    }

    private func appendNotice(_ kind: ChatNotice.Kind, _ title: String, detail: String? = nil) {
        let notice = ChatNotice(kind: kind, title: title, detail: detail)
        appendAssistant(ChatMessage(
            role: .assistant,
            blocks: [ChatBlock(content: .notice(notice))],
            plainText: [title, detail].compactMap { $0 }.joined(separator: "\n")
        ))
    }

    /// Finished replies appear after a short "thinking" beat (typing dots), so the thread
    /// doesn't snap a result in the instant something is asked. Running messages go in as they are.
    private func appendAssistant(_ message: ChatMessage, to conversationID: String? = nil) {
        let id = conversationID ?? current.id
        guard case .done = message.status else {
            modifyConversation(id) { $0.messages.append(message) }
            return
        }

        let placeholder = ChatMessage(role: .assistant, projectID: message.projectID, blocks: [], status: .running(label: ""))
        let placeholderID = placeholder.id
        modifyConversation(id) { $0.messages.append(placeholder) }

        let task = Task { [weak self] in
            try? await Task.sleep(for: Self.thinkingDelay)
            guard let self, !Task.isCancelled else { return }
            self.tasks[placeholderID] = nil
            self.updateMessage(placeholderID, in: id) { reply in
                reply.blocks = message.blocks
                reply.plainText = message.plainText
                reply.projectID = message.projectID
                reply.status = .done
                reply.date = Date()
            }
        }
        tasks[placeholderID] = RunningTask(conversationID: id, task: task)
    }

    private func updateMessage(_ messageID: String, in conversationID: String, _ body: (inout ChatMessage) -> Void) {
        modifyConversation(conversationID) { conversation in
            guard let index = conversation.messages.firstIndex(where: { $0.id == messageID }) else { return }
            body(&conversation.messages[index])
        }
    }

    /// Applies a change to the current conversation, or to a background one a finished task belongs to.
    private func modifyConversation(_ id: String, animated: Bool = true, _ body: (inout ChatConversation) -> Void) {
        if current.id == id {
            if animated {
                withAnimation(Self.animation) { body(&current) }
            } else {
                body(&current)
            }
            current.updatedAt = Date()
            syncCurrent()
        } else if let index = conversations.firstIndex(where: { $0.id == id }) {
            body(&conversations[index])
            conversations[index].updatedAt = Date()
            conversations.sort { $0.updatedAt > $1.updatedAt }
        } else {
            return
        }
        scheduleSave()
    }

    /// Keeps the current conversation in the history list once it has messages.
    private func syncCurrent() {
        guard !current.messages.isEmpty else { return }
        if let index = conversations.firstIndex(where: { $0.id == current.id }) {
            conversations[index] = current
        } else {
            conversations.insert(current, at: 0)
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
        if conversations.count > ChatStore.maxConversations {
            conversations = Array(conversations.prefix(ChatStore.maxConversations))
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            let snapshot = self.conversations
            await self.store.saveConversations(snapshot)
        }
    }
}
