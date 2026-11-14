import AppKit
import Foundation

/// Runs Chat actions against the app's existing services and turns the results into chat blocks.
/// There is no language model: every answer comes from one of these services.
struct ChatActionExecutor {
    typealias ActionResult = (blocks: [ChatBlock], followUps: [ChatAction], plainText: String)
    typealias CommandResult = (blocks: [ChatBlock], plainText: String)

    let appViewModel: AppViewModel

    static let unusedCodeItemLimit = 200
    static let largestFileLimit = 8
    static let recentProjectLimit = 8
    static let gitRangeDays = 30

    // MARK: - Available actions

    /// The numbered actions offered for a project, in display order.
    func availableActions(for project: ProjectInfo) -> [ChatAction] {
        var actions: [ChatAction] = [.gitActivity, .codeStats, .dependencies, .readme, .cacheSize, .unusedCode]
        if appViewModel.runner.getStartCommand(at: project.path) != nil {
            actions.append(.run(script: nil))
        }
        if project.isAppleProject {
            actions.append(.openInXcode)
        }
        for editor in appViewModel.installedEditors() {
            actions.append(.openInEditor(id: editor.id, name: editor.name))
        }
        actions += [.openTerminal, .revealInFinder, .addNote, .addTodo, .copyPath, .openInDevAtlas]
        return actions
    }

    /// Actions reachable by keyword only (they are offered as follow-ups, not in the numbered list).
    static let keywordOnlyActions: [ChatAction] = [.outdatedDependencies, .cleanCache]

    // MARK: - Actions

    @MainActor
    func execute(_ action: ChatAction, project: ProjectInfo) async -> ActionResult {
        switch action {
        case .gitActivity: return await gitActivity(project)
        case .codeStats: return await codeStats(project)
        case .dependencies: return await dependencies(project, checkLatest: false)
        case .outdatedDependencies: return await dependencies(project, checkLatest: true)
        case .unusedCode: return await unusedCode(project)
        case .cacheSize: return await cacheSize(project)
        case .cleanCache: return await cleanCache(project)
        case .cleanCacheConfirmed: return await cleanCacheConfirmed(project)
        case .readme: return await readme(project)
        case .run(let script): return run(project, script: script)
        case .openInDevAtlas:
            appViewModel.openProject(project)
            return instant(.success, "chat.notice.openedInDevAtlas".localized(project.name))
        case .openInXcode:
            appViewModel.openInXcode(project)
            return instant(.success, "chat.notice.openedIn".localized(project.name, "Xcode"))
        case .openInEditor(let id, let name):
            guard let editor = appViewModel.installedEditors().first(where: { $0.id == id }) else {
                return instant(.warning, "chat.notice.editorMissing".localized(name))
            }
            appViewModel.openInEditor(editor, project: project)
            return instant(.success, "chat.notice.openedIn".localized(project.name, editor.name))
        case .openTerminal:
            appViewModel.openTerminal(project)
            return instant(.success, "chat.notice.openedTerminal".localized(project.name))
        case .revealInFinder:
            appViewModel.revealInFinder(project)
            return instant(.success, "chat.notice.revealedInFinder".localized(project.name))
        case .copyPath:
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(project.path, forType: .string)
            return instant(.success, "chat.notice.copiedPath".localized, detail: project.path)
        case .openNote(let id):
            let notes = await NotebookStore.shared.loadNotes()
            guard notes.contains(where: { $0.id == id }) else {
                return instant(.warning, "chat.notice.noteMissing".localized)
            }
            // ContentView switches to the Notebook tab and selects the note.
            appViewModel.pendingNavigateToNoteId = id
            return instant(.success, "chat.notice.openedNote".localized)
        case .addNote, .addTodo:
            // Handled by the view model: it asks for the text first.
            return ([], [], "")
        }
    }

    // MARK: - Slash commands

    @MainActor
    func execute(_ command: ChatSlashCommand) async -> CommandResult {
        switch command {
        case .recent:
            let projects = Array(appViewModel.menuProjects.prefix(Self.recentProjectLimit))
            guard !projects.isEmpty else {
                let notice = ChatNotice(kind: .info, title: "chat.notice.noProjects".localized,
                                        detail: "chat.notice.noProjects.detail".localized)
                return ([ChatBlock(content: .notice(notice))], notice.title)
            }
            let title = "chat.card.recent.title".localized
            return ([ChatBlock(content: .projectList(title: title, projects: projects))],
                    Self.plainList(title: title, projects: projects))
        case .ports:
            await appViewModel.portManager.refresh()
            if let error = appViewModel.portManager.errorMessage {
                let notice = ChatNotice(kind: .error, title: error)
                return ([ChatBlock(content: .notice(notice))], error)
            }
            let rows = appViewModel.projectPortListeners
            let lines = rows.map { row in
                "\(row.port) · \(row.command) · PID \(row.pid) · \(appViewModel.project(for: row)?.name ?? row.workingDirectory ?? "—")"
            }
            return ([ChatBlock(content: .ports(rows))], (["tab.ports".localized] + lines).joined(separator: "\n"))
        case .stats:
            return workspaceStats()
        case .rescan:
            let notice = ChatNotice(kind: .info, title: "chat.running.rescan".localized)
            return ([ChatBlock(content: .notice(notice))], notice.title)
        case .new:
            return ([], "")
        case .help:
            let text = "chat.help.body".localized
            return ([ChatBlock(content: .text(text))], text)
        }
    }

    /// Rescans every drive and returns the number of projects found.
    @MainActor
    func rescan() async -> Int {
        await appViewModel.startScan()
        return appViewModel.projects.count
    }

    // MARK: - Notebook

    /// Saves `text` as a new note on the project and returns the note's id.
    func saveNote(text: String, project: ProjectInfo) async -> String {
        let now = Date()
        let note = NotebookNote(
            projectId: project.id,
            projectName: project.name,
            title: Self.noteTitle(from: text),
            content: text,
            todos: [],
            createdAt: now,
            updatedAt: now
        )
        _ = await NotebookStore.shared.addNote(note)
        await Self.notifyNotebook()
        return note.id
    }

    /// Adds a to-do to the project's most recently edited note, or to a new one. Returns the note's id.
    func saveTodo(text: String, project: ProjectInfo) async -> String {
        let store = NotebookStore.shared
        let notes = await store.loadNotes()
        let todo = TodoItem(text: text)
        let candidates = notes.filter { note in
            note.isArchived != true && (note.projectId == project.id || note.projectName == project.name)
        }

        if var note = candidates.max(by: { $0.updatedAt < $1.updatedAt }) {
            note.todos.append(todo)
            note.updatedAt = Date()
            _ = await store.updateNote(note)
            await Self.notifyNotebook()
            return note.id
        }

        let now = Date()
        let note = NotebookNote(
            projectId: project.id,
            projectName: project.name,
            title: "chat.note.todoTitle".localized,
            content: "",
            todos: [todo],
            createdAt: now,
            updatedAt: now
        )
        _ = await store.addNote(note)
        await Self.notifyNotebook()
        return note.id
    }

    private static func noteTitle(from text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 60 else { return trimmed.isEmpty ? "chat.note.untitled".localized : trimmed }
        return String(trimmed.prefix(60)) + "…"
    }

    @MainActor
    private static func notifyNotebook() {
        NotificationCenter.default.post(name: NSNotification.Name("NotebookNotesUpdated"), object: nil)
    }

    // MARK: - Git

    @MainActor
    private func gitActivity(_ project: ProjectInfo) async -> ActionResult {
        async let stateResult = ProjectOverviewService.gitSummary(at: project.path)
        async let statsResult = GitStatsService.shared.fetchGitStats(for: [project], in: .month)
        let state = await stateResult
        let stats = await statsResult

        let summary: ProjectGitSummary
        switch state {
        case .repository(let value):
            summary = value
        case .notRepository:
            return notice(.info, "chat.notice.notGitRepo".localized(project.name), followUps: [.codeStats, .openTerminal])
        case .unavailable:
            return notice(.warning, "chat.notice.gitUnavailable".localized, followUps: [.openTerminal])
        }

        // One entry per day of the range, so the chart has no gaps.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var byDay: [Date: ChatGitPayload.Day] = [:]
        for offset in 0..<Self.gitRangeDays {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            byDay[date] = .init(date: date, additions: 0, deletions: 0, commits: 0)
        }
        for stat in stats {
            let day = calendar.startOfDay(for: stat.date)
            guard var entry = byDay[day] else { continue }
            entry.additions += stat.additions
            entry.deletions += stat.deletions
            entry.commits += stat.commits
            byDay[day] = entry
        }

        let payload = ChatGitPayload(
            isRepository: true,
            branch: summary.branch,
            changedFiles: summary.changedFiles,
            lastCommitHash: summary.commit?.hash,
            lastCommitSubject: summary.commit?.subject,
            lastCommitDate: summary.commit?.date,
            remoteURL: summary.remoteURL,
            rangeDays: Self.gitRangeDays,
            days: byDay.values.sorted { $0.date < $1.date }
        )

        var lines = ["chat.plain.git.header".localized(project.name)]
        if let branch = payload.branch { lines.append("chat.plain.git.branch".localized(branch)) }
        lines.append("chat.plain.git.changedFiles".localized(payload.changedFiles))
        if let hash = payload.lastCommitHash {
            lines.append("chat.plain.git.lastCommit".localized(hash, payload.lastCommitSubject ?? ""))
        }
        lines.append("chat.plain.git.activity".localized(payload.totalCommits, payload.totalAdditions, payload.totalDeletions))
        if let remote = payload.remoteURL { lines.append(remote.absoluteString) }

        return ([ChatBlock(content: .git(payload))], [.codeStats, .openTerminal], lines.joined(separator: "\n"))
    }

    // MARK: - Code stats

    @MainActor
    private func codeStats(_ project: ProjectInfo) async -> ActionResult {
        async let analysisResult = CodeAnalyzer.analyze(for: project)
        async let statsResult = ProjectStatistics.calculate(for: project)
        let analysis = await analysisResult
        let stats = await statsResult

        guard analysis.totalFiles > 0 else {
            return notice(.info, "chat.notice.noSourceFiles".localized(project.name), followUps: [.dependencies])
        }

        let languages = analysis.languageBreakdown
            .sorted { $0.percentage > $1.percentage }
            .map { ChatCodeStatsPayload.Language(name: $0.language, percentage: $0.percentage, colorHex: $0.color) }
        let largest = analysis.files
            .sorted { $0.lineCount > $1.lineCount }
            .prefix(Self.largestFileLimit)
            .map { ChatCodeStatsPayload.File(path: $0.relativePath, lines: $0.lineCount) }

        let payload = ChatCodeStatsPayload(
            totalFiles: analysis.totalFiles,
            totalLines: analysis.totalLines,
            sizeOnDisk: stats.totalSize,
            languages: languages,
            largestFiles: Array(largest)
        )

        var lines = ["chat.plain.code.header".localized(project.name),
                     "chat.plain.code.summary".localized(payload.totalFiles, payload.totalLines, payload.sizeOnDisk)]
        if !languages.isEmpty {
            lines.append(languages.prefix(6)
                .map { "\($0.name) \(String(format: "%.1f", $0.percentage))%" }
                .joined(separator: " · "))
        }
        if !payload.largestFiles.isEmpty {
            lines.append("chat.plain.code.largest".localized)
            lines += payload.largestFiles.map { "  \($0.path) — \($0.lines)" }
        }

        return ([ChatBlock(content: .codeStats(payload))], [.unusedCode, .dependencies], lines.joined(separator: "\n"))
    }

    // MARK: - Dependencies

    @MainActor
    private func dependencies(_ project: ProjectInfo, checkLatest: Bool) async -> ActionResult {
        var found = await DependenciesService.getDependencies(for: project)
        guard found.hasDependencies, found.totalCount > 0 else {
            return notice(.info, "chat.notice.noDependencies".localized(project.name), followUps: [.codeStats])
        }
        if checkLatest {
            found = await VersionCheckerService.enrichWithLatestVersions(found)
        }

        var grouped: [String: [Dependency]] = [:]
        for group in found.projectGroups {
            grouped[group.projectName, default: []] += group.dependencies
        }
        let payload = ChatDependenciesPayload(
            direct: found.directDependencies,
            dev: found.devDependencies,
            grouped: grouped,
            checkedLatest: checkLatest
        )

        var lines = ["chat.plain.deps.header".localized(project.name, payload.all.count)]
        if checkLatest {
            let outdated = payload.outdated
            lines.append("chat.plain.deps.outdated".localized(outdated.count))
            lines += outdated.map { "  \($0.name) \($0.displayVersion) → \($0.latestVersion ?? "")" }
        } else {
            lines += payload.all.map { "  \($0.name) \($0.displayVersion)" }
        }

        let followUps: [ChatAction] = checkLatest ? [] : [.outdatedDependencies]
        return ([ChatBlock(content: .dependencies(payload))], followUps, lines.joined(separator: "\n"))
    }

    // MARK: - Unused code

    @MainActor
    private func unusedCode(_ project: ProjectInfo) async -> ActionResult {
        let analyzer = UnusedCodeAnalyzer()
        let results: [UnusedCodeResult]
        do {
            results = try await analyzer.analyze(projectPath: project.path)
        } catch AnalyzerError.unsupportedLanguage(let language) {
            return notice(.info, "chat.notice.unusedUnsupported".localized(language))
        } catch {
            return notice(.error, "chat.notice.unusedFailed".localized, detail: Self.describe(error))
        }

        guard !results.isEmpty else {
            return notice(.success, "analyze.noUnusedCode".localized, followUps: [.codeStats])
        }

        let items = results.prefix(Self.unusedCodeItemLimit).map {
            ChatUnusedCodePayload.Item(kind: $0.kind, name: $0.name, location: $0.location)
        }
        let payload = ChatUnusedCodePayload(
            items: Array(items),
            totalCount: results.count,
            removalPrompt: analyzer.generateRemovalPrompt(from: results, projectPath: project.path)
        )

        var lines = ["chat.plain.unused.header".localized(project.name, results.count)]
        lines += payload.items.map { "  \($0.kind) \($0.name) — \($0.location)" }
        return ([ChatBlock(content: .unusedCode(payload))], [.codeStats], lines.joined(separator: "\n"))
    }

    private static func describe(_ error: Error) -> String {
        if case AnalyzerError.executionFailed(let message) = error { return message }
        if case AnalyzerError.parsingFailed = error { return "chat.notice.unusedParsingFailed".localized }
        return error.localizedDescription
    }

    // MARK: - Cache

    @MainActor
    private func cacheSize(_ project: ProjectInfo) async -> ActionResult {
        let folders = await measureCaches(project)
        guard !folders.isEmpty else {
            return notice(.success, "cache.empty.title".localized, detail: "chat.notice.noCaches.detail".localized(project.name))
        }
        let payload = ChatCachePayload(folders: folders)
        return ([ChatBlock(content: .cache(payload))], [.cleanCache], Self.plainCache(payload, project: project))
    }

    @MainActor
    private func cleanCache(_ project: ProjectInfo) async -> ActionResult {
        let folders = await measureCaches(project)
        guard !folders.isEmpty else {
            return notice(.success, "cache.empty.title".localized, detail: "chat.notice.noCaches.detail".localized(project.name))
        }
        let payload = ChatCachePayload(folders: folders)
        let size = payload.totalBytes.chatByteString
        let confirmation = ChatConfirmation(
            action: .cleanCacheConfirmed,
            title: "cache.confirm.title".localized(size),
            message: "cache.confirm.message".localized(folders.count),
            confirmLabel: "cache.confirm.trash".localized,
            isDestructive: true
        )
        return ([ChatBlock(content: .cache(payload)), ChatBlock(content: .confirm(confirmation))],
                [],
                Self.plainCache(payload, project: project) + "\n" + confirmation.title)
    }

    @MainActor
    private func cleanCacheConfirmed(_ project: ProjectInfo) async -> ActionResult {
        // Measured again rather than trusting paths from the saved conversation.
        let folders = await measureCaches(project)
        guard !folders.isEmpty else {
            return notice(.success, "cache.empty.title".localized, detail: "chat.notice.noCaches.detail".localized(project.name))
        }

        var freed: Int64 = 0
        var failed = 0
        for folder in folders {
            let path = folder.path
            let removed = await Task.detached(priority: .userInitiated) {
                do {
                    try ProjectCacheScanner.remove(path, toTrash: true)
                    return true
                } catch {
                    // Already gone counts as cleaned.
                    return !FileManager.default.fileExists(atPath: path)
                }
            }.value
            if removed {
                freed += folder.bytes
            } else {
                failed += 1
            }
        }

        var payload = ChatCachePayload(folders: folders)
        payload.freedBytes = freed
        payload.failedCount = failed

        let result = ChatNotice(
            kind: failed == 0 ? .success : .warning,
            title: "cache.result.freed".localized(freed.chatByteString),
            detail: failed > 0 ? "cache.result.failed".localized(failed) : "chat.notice.movedToTrash".localized
        )
        var plain = result.title
        if let detail = result.detail { plain += "\n" + detail }
        return ([ChatBlock(content: .cache(payload)), ChatBlock(content: .notice(result))], [.cacheSize], plain)
    }

    /// Mirrors ProjectCacheViewModel.measure for a single project.
    @MainActor
    private func measureCaches(_ project: ProjectInfo) async -> [ChatCachePayload.Folder] {
        let path = project.path
        // Projects nested inside this one are measured on their own, so the walk stops at them.
        let nested = Set(appViewModel.projects.map(\.path).filter { $0 != path && $0.hasPrefix(path + "/") })

        let items = await Task.detached(priority: .userInitiated) { () -> [CacheItem] in
            var items = ProjectCacheScanner.caches(inProjectAt: path, skipping: nested)
            let derived = ProjectCacheScanner.derivedData(forProjectsAt: [path] + Array(nested))[path] ?? []
            for var item in derived where !items.contains(where: { $0.path == item.path }) {
                item.size = ProjectCacheScanner.directorySize(atPath: item.path)
                if item.size > 0 { items.append(item) }
            }
            return items.sorted { ($0.size, $1.displayName) > ($1.size, $0.displayName) }
        }.value

        return items.map {
            ChatCachePayload.Folder(path: $0.path, displayName: $0.displayName, kindTitleKey: $0.kind.titleKey, bytes: $0.size)
        }
    }

    private static func plainCache(_ payload: ChatCachePayload, project: ProjectInfo) -> String {
        var lines = ["chat.plain.cache.header".localized(project.name, payload.totalBytes.chatByteString)]
        lines += payload.folders.map { "  \($0.displayName) — \($0.bytes.chatByteString)" }
        return lines.joined(separator: "\n")
    }

    // MARK: - README

    @MainActor
    private func readme(_ project: ProjectInfo) async -> ActionResult {
        switch await ProjectOverviewService.readme(at: project.path) {
        case .document(let readme):
            let payload = ChatReadmePayload(
                fileURL: readme.url,
                preview: readme.preview,
                isMarkdown: readme.isMarkdown,
                isTruncated: readme.content.count > readme.preview.count
            )
            return ([ChatBlock(content: .readme(payload))], [.gitActivity, .codeStats], readme.preview)
        case .missing:
            return notice(.info, "chat.notice.noReadme".localized(project.name), followUps: [.addNote])
        case .tooLarge(let url):
            return notice(.info, "chat.notice.readmeTooLarge".localized(url.lastPathComponent), followUps: [.revealInFinder])
        case .unreadable:
            return notice(.warning, "chat.notice.readmeUnreadable".localized)
        }
    }

    // MARK: - Run

    @MainActor
    private func run(_ project: ProjectInfo, script: String?) -> ActionResult {
        let runner = appViewModel.runner
        let scripts = runner.getAllScripts(at: project.path)

        let name: String
        if let script {
            // Only names read back from package.json are ever passed to Terminal.
            guard let match = scripts.first(where: { $0.name == script }) else {
                return notice(.warning, "chat.notice.scriptMissing".localized(script))
            }
            name = match.name
        } else if scripts.count > 1 {
            let items = scripts.map { ChatScript(name: $0.name, command: $0.command) }
            let lines = ["chat.plain.scripts.header".localized(project.name)] + items.map { "  \($0.name): \($0.command)" }
            return ([ChatBlock(content: .text("chat.message.pickScript".localized)), ChatBlock(content: .scripts(items))],
                    [], lines.joined(separator: "\n"))
        } else if let start = runner.getStartCommand(at: project.path), scripts.contains(where: { $0.name == start }) {
            name = start
        } else if let only = scripts.first {
            name = only.name
        } else {
            return notice(.info, "chat.notice.nothingToRun".localized(project.name))
        }

        appViewModel.runProject(project, script: name)
        return instant(.success, "chat.notice.startedScript".localized(name))
    }

    // MARK: - Workspace stats

    @MainActor
    private func workspaceStats() -> CommandResult {
        let projects = appViewModel.projects
        guard !projects.isEmpty else {
            let notice = ChatNotice(kind: .info, title: "chat.notice.noProjects".localized,
                                    detail: "chat.notice.noProjects.detail".localized)
            return ([ChatBlock(content: .notice(notice))], notice.title)
        }

        let byCategory = ProjectCategory.allCases.compactMap { category -> ChatWorkspaceStatsPayload.Slice? in
            let count = projects.filter { $0.category == category }.count
            guard count > 0 else { return nil }
            return .init(name: category.rawValue, count: count, colorHex: Self.categoryColors[category])
        }
        .sorted { $0.count > $1.count }

        let languageCounts = Dictionary(projects.map { ($0.language, 1) }, uniquingKeysWith: +)
        let byLanguage = languageCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(6)
            .map { ChatWorkspaceStatsPayload.Slice(name: $0.key, count: $0.value, colorHex: Self.languageColors[$0.key]) }

        let payload = ChatWorkspaceStatsPayload(
            projectCount: projects.count,
            totalFiles: projects.compactMap(\.totalFiles).reduce(0, +),
            totalLines: projects.compactMap(\.totalLines).reduce(0, +),
            byCategory: byCategory,
            byLanguage: Array(byLanguage)
        )

        var lines = ["chat.plain.workspace.summary".localized(payload.projectCount, payload.totalFiles, payload.totalLines)]
        lines.append(byCategory.map { "\($0.name) \($0.count)" }.joined(separator: " · "))
        lines.append(payload.byLanguage.map { "\($0.name) \($0.count)" }.joined(separator: " · "))
        return ([ChatBlock(content: .workspaceStats(payload))], lines.joined(separator: "\n"))
    }

    private static let categoryColors: [ProjectCategory: String] = [
        .web: "0A84FF", .desktop: "5E5CE6", .mobile: "30B158", .cloud: "64D2FF", .other: "8E8E93",
    ]

    /// Same hues as CodeAnalyzer's language palette, for the languages projects are grouped by.
    private static let languageColors: [String: String] = [
        "Swift": "FA7343", "Objective-C": "438EFF", "C": "555555", "C++": "F34B7D",
        "C#": "178600", "F#": "B845FC", "Visual Basic": "945DB7",
        "Java": "B07219", "Kotlin": "A97BFF", "Scala": "C22D40",
        "Go": "00ADD8", "Rust": "DEA584", "Zig": "EC915C",
        "Python": "3572A5", "Ruby": "701516", "PHP": "4F5D95", "Dart": "00B4AB",
        "JavaScript": "F1E05A", "TypeScript": "3178C6", "Elixir": "6E4A7E", "Lua": "000080",
    ]

    // MARK: - Helpers

    private func notice(_ kind: ChatNotice.Kind, _ title: String, detail: String? = nil,
                        followUps: [ChatAction] = []) -> ActionResult {
        let notice = ChatNotice(kind: kind, title: title, detail: detail)
        let plain = [title, detail].compactMap { $0 }.joined(separator: "\n")
        return ([ChatBlock(content: .notice(notice))], followUps, plain)
    }

    private func instant(_ kind: ChatNotice.Kind, _ title: String, detail: String? = nil) -> ActionResult {
        notice(kind, title, detail: detail)
    }

    static func plainList(title: String, projects: [ProjectInfo]) -> String {
        ([title] + projects.enumerated().map { "\($0.offset + 1). \($0.element.name) — \($0.element.path)" })
            .joined(separator: "\n")
    }
}
