import SwiftUI
import AppKit
import Combine

/// Something the quick search panel can do with the chosen project.
struct QuickSearchAction: Identifiable {
    let id: String
    let title: String
    var subtitle: String?
    let systemImage: String
    let tint: Color
    let run: () -> Void
}

/// A project that matched the query, with the characters of its name that matched.
struct QuickSearchMatch: Identifiable {
    let project: ProjectInfo
    let score: Int
    let matchedIndices: Set<Int>

    var id: String { project.id }
}

/// State behind the quick search panel: first pick a project, then pick what to do with it.
final class QuickSearchModel: ObservableObject {
    enum Stage: Equatable {
        case projects
        case actions(ProjectInfo)
    }

    @Published private(set) var stage: Stage = .projects
    @Published var query: String = "" {
        didSet { if query != oldValue { selection = 0 } }
    }
    @Published var selection: Int = 0
    /// Bumped to put the cursor back in the search field.
    @Published private(set) var focusRequest: Int = 0

    /// Shown when nothing is typed.
    static let recentLimit = 8
    private static let resultLimit = 50

    private let viewModel: AppViewModel
    private var parentObserver: AnyCancellable?
    /// Closes the panel before an action runs, so apps it opens come to the front.
    var onFinish: () -> Void = {}
    /// Shows the project in the main window.
    var onOpenInApp: (ProjectInfo) -> Void = { _ in }

    /// The search typed before stepping into a project's actions, restored on the way back.
    @Published private var projectQuery = ""
    @Published private var projectSelection = 0
    @Published private var stageActions: [QuickSearchAction] = []

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        parentObserver = viewModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - Results

    var isShowingRecent: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasAnyProjects: Bool { !viewModel.menuProjects.isEmpty }

    var matches: [QuickSearchMatch] {
        let projects = viewModel.menuProjects
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return projects.prefix(Self.recentLimit).map { QuickSearchMatch(project: $0, score: 0, matchedIndices: []) }
        }

        let found = projects.compactMap { project -> QuickSearchMatch? in
            if let nameMatch = Self.match(trimmed, in: project.name) {
                return QuickSearchMatch(project: project, score: nameMatch.score, matchedIndices: nameMatch.indices)
            }
            let needle = trimmed.lowercased()
            let otherFields = [project.path, project.projectType] + project.tags
            if otherFields.contains(where: { $0.lowercased().contains(needle) }) {
                return QuickSearchMatch(project: project, score: 50, matchedIndices: [])
            }
            return nil
        }
        // Stable sort keeps the newest first among equally good matches.
        return Array(
            found.enumerated()
                .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
                .map(\.element)
                .prefix(Self.resultLimit)
        )
    }

    var actions: [QuickSearchAction] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return stageActions }
        return stageActions.filter { Self.match(trimmed, in: $0.title) != nil }
    }

    private var itemCount: Int {
        switch stage {
        case .projects: return matches.count
        case .actions: return actions.count
        }
    }

    // MARK: - Lifecycle

    /// Starts over each time the panel opens.
    func reset() {
        stage = .projects
        query = ""
        projectQuery = ""
        selection = 0
        stageActions = []
        focusRequest += 1
    }

    /// Puts the cursor in the search field, once the panel can take it.
    func requestFocus() {
        focusRequest += 1
    }

    // MARK: - Keyboard

    func moveSelection(by offset: Int) {
        let count = itemCount
        guard count > 0 else { return }
        selection = (selection + offset + count) % count
    }

    /// Return: a project steps into its actions, an action runs.
    func activateSelection() {
        switch stage {
        case .projects:
            let matches = matches
            guard matches.indices.contains(selection) else { return }
            showActions(for: matches[selection].project)
        case .actions:
            let actions = actions
            guard actions.indices.contains(selection) else { return }
            perform(actions[selection])
        }
    }

    /// Command-Return skips the action list and opens the project in DevAtlas.
    func activateDefault() {
        switch stage {
        case .projects:
            let matches = matches
            guard matches.indices.contains(selection) else { return }
            let project = matches[selection].project
            onFinish()
            onOpenInApp(project)
        case .actions:
            activateSelection()
        }
    }

    /// Command-1…9 runs the listed action with that number.
    func performAction(number: Int) -> Bool {
        guard case .actions = stage else { return false }
        let actions = actions
        guard actions.indices.contains(number - 1) else { return false }
        perform(actions[number - 1])
        return true
    }

    /// Escape: back out of the actions, then clear the search, then close.
    /// Returns false when there is nothing left to back out of.
    func goBack() -> Bool {
        switch stage {
        case .actions:
            backToProjects()
            return true
        case .projects:
            guard !query.isEmpty else { return false }
            query = ""
            return true
        }
    }

    /// Delete with an empty field leaves the actions, as in Spotlight.
    func deleteBackwardOnEmpty() -> Bool {
        guard case .actions = stage, query.isEmpty else { return false }
        backToProjects()
        return true
    }

    var isShowingActions: Bool {
        if case .actions = stage { return true }
        return false
    }

    // MARK: - Stages

    func showActions(for project: ProjectInfo) {
        projectQuery = query
        projectSelection = selection
        stageActions = buildActions(for: project)
        withAnimation(.snappy(duration: 0.22)) {
            stage = .actions(project)
            query = ""
            selection = 0
        }
        focusRequest += 1
    }

    func backToProjects() {
        withAnimation(.snappy(duration: 0.22)) {
            stage = .projects
            query = projectQuery
            selection = projectSelection
        }
        stageActions = []
        focusRequest += 1
    }

    func perform(_ action: QuickSearchAction) {
        onFinish()
        action.run()
    }

    private func buildActions(for project: ProjectInfo) -> [QuickSearchAction] {
        let viewModel = viewModel
        var actions: [QuickSearchAction] = [
            QuickSearchAction(
                id: "devatlas",
                title: "quickSearch.openInDevAtlas".localized,
                systemImage: "square.grid.2x2.fill",
                tint: .daAccent
            ) { [onOpenInApp] in onOpenInApp(project) }
        ]

        if project.isAppleProject {
            actions.append(QuickSearchAction(
                id: "xcode",
                title: "projects.openInXcode".localized,
                systemImage: "hammer.fill",
                tint: Color(hex: "1C7CF4")
            ) { viewModel.openInXcode(project) })
        }

        for editor in viewModel.installedEditors() {
            actions.append(QuickSearchAction(
                id: "editor.\(editor.id)",
                title: "quickSearch.openIn".localized(editor.name),
                systemImage: "chevron.left.forwardslash.chevron.right",
                tint: Color(hex: "8B5CF6")
            ) { viewModel.openInEditor(editor, project: project) })
        }

        if let script = viewModel.runner.getStartCommand(at: project.path) {
            actions.append(QuickSearchAction(
                id: "run",
                title: "projects.runProject".localized,
                subtitle: script,
                systemImage: "play.fill",
                tint: .daGreen
            ) { viewModel.runProject(project, script: script) })
        }

        actions.append(contentsOf: [
            QuickSearchAction(
                id: "terminal",
                title: "projects.openTerminal".localized,
                systemImage: "terminal.fill",
                tint: Color(hex: "3A3A3C")
            ) { viewModel.openTerminal(project) },
            QuickSearchAction(
                id: "finder",
                title: "projects.revealInFinder".localized,
                systemImage: "folder.fill",
                tint: Color(hex: "0EA5E9")
            ) { viewModel.revealInFinder(project) },
            QuickSearchAction(
                id: "copyPath",
                title: "finder.copyPath".localized,
                subtitle: (project.path as NSString).abbreviatingWithTildeInPath,
                systemImage: "doc.on.doc.fill",
                tint: .daOrange
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(project.path, forType: .string)
            }
        ])
        return actions
    }

    // MARK: - Matching

    /// Scores `query` against `text`: a prefix beats a word start, which beats a match inside a
    /// word, which beats letters spread out (so "dam" finds "DevAtlasMac").
    static func match(_ query: String, in text: String) -> (score: Int, indices: Set<Int>)? {
        // Compared one character at a time so indices line up with `text`'s characters.
        let haystack = text.map { String($0).lowercased() }
        let needle = query.filter { !$0.isWhitespace }.map { String($0).lowercased() }
        guard !needle.isEmpty, needle.count <= haystack.count else { return nil }

        if let start = contiguousMatch(needle, in: haystack) {
            let indices = Set(start..<(start + needle.count))
            if start == 0 { return (1000 - haystack.count, indices) }
            let isWordStart = isWordBoundary(at: start, in: text)
            return ((isWordStart ? 800 : 600) - start, indices)
        }

        var indices: Set<Int> = []
        var searchFrom = 0
        var gaps = 0
        var wordStarts = 0
        for character in needle {
            guard let found = haystack[searchFrom...].firstIndex(of: character) else { return nil }
            gaps += found - searchFrom
            if isWordBoundary(at: found, in: text) { wordStarts += 1 }
            indices.insert(found)
            searchFrom = found + 1
        }
        return (300 + wordStarts * 40 - gaps * 3, indices)
    }

    private static func contiguousMatch(_ needle: [String], in haystack: [String]) -> Int? {
        guard needle.count <= haystack.count else { return nil }
        for start in 0...(haystack.count - needle.count) where haystack[start] == needle[0] {
            if Array(haystack[start..<(start + needle.count)]) == needle { return start }
        }
        return nil
    }

    /// The start of a word: after a separator, or an uppercase letter after a lowercase one.
    private static func isWordBoundary(at index: Int, in text: String) -> Bool {
        guard index > 0 else { return true }
        let characters = Array(text)
        let previous = characters[index - 1]
        let current = characters[index]
        if previous == " " || previous == "-" || previous == "_" || previous == "." || previous == "/" { return true }
        return current.isUppercase && previous.isLowercase
    }
}
