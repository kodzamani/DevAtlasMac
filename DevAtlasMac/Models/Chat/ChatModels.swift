import Foundation

// Shared types for the Chat tab: a conversational command interface over the user's projects.
// There is no language model behind it. The "assistant" answers by running existing services.

enum ChatRole: String, Codable { case user, assistant }

enum ChatMessageStatus: Codable, Hashable {
    case done
    case running(label: String)      // already-localized label, e.g. "Analyzing code…"
    case failed
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var role: ChatRole
    var date: Date = Date()
    /// Project this message is about; action chips inside it run against this project.
    var projectID: String?
    var blocks: [ChatBlock]
    var status: ChatMessageStatus = .done
    /// Plain text for the copy button (user text, or a text rendering of the result).
    var plainText: String = ""
}

struct ChatConversation: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var title: String = ""               // first user message / first project name
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var activeProjectID: String?
    var messages: [ChatMessage] = []
}

struct ChatBlock: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var content: ChatContent
}

enum ChatContent: Codable, Hashable {
    case text(String)                               // short markdown
    case notice(ChatNotice)
    case project(ProjectInfo)                       // project card
    case actions([ChatAction])                      // numbered action chips/cards
    case projectList(title: String, projects: [ProjectInfo])
    case scripts([ChatScript])                      // pick a package.json script
    case confirm(ChatConfirmation)
    case git(ChatGitPayload)
    case codeStats(ChatCodeStatsPayload)
    case dependencies(ChatDependenciesPayload)
    case unusedCode(ChatUnusedCodePayload)
    case cache(ChatCachePayload)
    case readme(ChatReadmePayload)
    case workspaceStats(ChatWorkspaceStatsPayload)
}

struct ChatNotice: Codable, Hashable {
    enum Kind: String, Codable { case success, info, warning, error }
    var kind: Kind
    var title: String
    var detail: String?
}

struct ChatScript: Codable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var command: String
}

struct ChatConfirmation: Codable, Hashable {
    enum State: String, Codable { case pending, confirmed, cancelled }
    var action: ChatAction          // what runs on confirm (e.g. .cleanCacheConfirmed)
    var title: String
    var message: String
    var confirmLabel: String
    var isDestructive: Bool
    var state: State = .pending
}

struct ChatGitPayload: Codable, Hashable {
    struct Day: Codable, Hashable, Identifiable {
        var id: Date { date }
        var date: Date
        var additions: Int
        var deletions: Int
        var commits: Int
    }
    var isRepository: Bool
    var branch: String?
    var changedFiles: Int
    var lastCommitHash: String?
    var lastCommitSubject: String?
    var lastCommitDate: Date?
    var remoteURL: URL?
    var rangeDays: Int                // 30
    var days: [Day]                   // sorted ascending; the user's own commits only
    var totalCommits: Int { days.reduce(0) { $0 + $1.commits } }
    var totalAdditions: Int { days.reduce(0) { $0 + $1.additions } }
    var totalDeletions: Int { days.reduce(0) { $0 + $1.deletions } }
}

struct ChatCodeStatsPayload: Codable, Hashable {
    struct Language: Codable, Hashable, Identifiable {
        var id: String { name }
        var name: String
        var percentage: Double
        var colorHex: String
    }
    struct File: Codable, Hashable, Identifiable {
        var id: String { path }
        var path: String
        var lines: Int
    }
    var totalFiles: Int
    var totalLines: Int
    var sizeOnDisk: String
    var languages: [Language]
    var largestFiles: [File]          // top 8
}

struct ChatDependenciesPayload: Codable, Hashable {
    var direct: [Dependency]
    var dev: [Dependency]
    var grouped: [String: [Dependency]]   // .NET project name -> deps
    var checkedLatest: Bool               // true after the outdated check
    var all: [Dependency] { direct + dev + grouped.values.flatMap { $0 } }
    var outdated: [Dependency] { all.filter(\.isUpgradeable) }
}

struct ChatUnusedCodePayload: Codable, Hashable {
    struct Item: Codable, Hashable, Identifiable {
        var id: String { "\(kind)|\(name)|\(location)" }
        var kind: String
        var name: String
        var location: String
    }
    var items: [Item]                 // capped at 200
    var totalCount: Int
    var removalPrompt: String?        // from UnusedCodeAnalyzer.generateRemovalPrompt
}

struct ChatCachePayload: Codable, Hashable {
    struct Folder: Codable, Hashable, Identifiable {
        var id: String { path }
        var path: String
        var displayName: String
        var kindTitleKey: String
        var bytes: Int64
    }
    var folders: [Folder]
    var totalBytes: Int64 { folders.reduce(0) { $0 + $1.bytes } }
    /// Set on the result that follows a clean.
    var freedBytes: Int64?
    var failedCount: Int = 0
}

struct ChatReadmePayload: Codable, Hashable {
    var fileURL: URL
    var preview: String               // ProjectReadme.preview (<= 6000 chars)
    var isMarkdown: Bool
    var isTruncated: Bool
}

struct ChatWorkspaceStatsPayload: Codable, Hashable {
    struct Slice: Codable, Hashable, Identifiable {
        var id: String { name }
        var name: String
        var count: Int
        var colorHex: String?
    }
    var projectCount: Int
    var totalFiles: Int               // sum of known ProjectInfo.totalFiles
    var totalLines: Int
    var byCategory: [Slice]
    var byLanguage: [Slice]           // top 6 by project count
}

// MARK: - Actions

/// What the assistant can do for a project.
enum ChatAction: Codable, Hashable, Identifiable {
    case openInDevAtlas
    case openInXcode
    case openInEditor(id: String, name: String)
    case openTerminal
    case revealInFinder
    case copyPath
    case run(script: String?)             // nil -> default script, or script picker when several
    case gitActivity
    case codeStats
    case dependencies
    case outdatedDependencies
    case unusedCode
    case cacheSize
    case cleanCache                       // produces a .confirm block
    case cleanCacheConfirmed              // only reachable through confirmation
    case readme
    case addNote
    case addTodo
    case openNote(id: String)             // follow-up only

    var id: String {
        switch self {
        case .openInDevAtlas: return "openInDevAtlas"
        case .openInXcode: return "openInXcode"
        case .openInEditor(let id, _): return "openInEditor:\(id)"
        case .openTerminal: return "openTerminal"
        case .revealInFinder: return "revealInFinder"
        case .copyPath: return "copyPath"
        case .run(let script): return "run:\(script ?? "")"
        case .gitActivity: return "gitActivity"
        case .codeStats: return "codeStats"
        case .dependencies: return "dependencies"
        case .outdatedDependencies: return "outdatedDependencies"
        case .unusedCode: return "unusedCode"
        case .cacheSize: return "cacheSize"
        case .cleanCache: return "cleanCache"
        case .cleanCacheConfirmed: return "cleanCacheConfirmed"
        case .readme: return "readme"
        case .addNote: return "addNote"
        case .addTodo: return "addTodo"
        case .openNote(let id): return "openNote:\(id)"
        }
    }

    /// Localized at render time so it follows language changes.
    var title: String {
        switch self {
        case .openInDevAtlas: return "quickSearch.openInDevAtlas".localized
        case .openInXcode: return "projects.openInXcode".localized
        case .openInEditor(_, let name): return "quickSearch.openIn".localized(name)
        case .openTerminal: return "projects.openTerminal".localized
        case .revealInFinder: return "projects.revealInFinder".localized
        case .copyPath: return "finder.copyPath".localized
        case .run(let script):
            if let script { return "chat.action.runScript".localized(script) }
            return "projects.runProject".localized
        case .gitActivity: return "chat.action.gitActivity".localized
        case .codeStats: return "chat.action.codeStats".localized
        case .dependencies: return "chat.action.dependencies".localized
        case .outdatedDependencies: return "chat.action.outdatedDependencies".localized
        case .unusedCode: return "chat.action.unusedCode".localized
        case .cacheSize: return "chat.action.cacheSize".localized
        case .cleanCache, .cleanCacheConfirmed: return "chat.action.cleanCache".localized
        case .readme: return "chat.action.readme".localized
        case .addNote: return "chat.action.addNote".localized
        case .addTodo: return "chat.action.addTodo".localized
        case .openNote: return "chat.action.openNote".localized
        }
    }

    var glyph: ChatGlyph {
        switch self {
        case .openInDevAtlas: return .grid
        case .openInXcode: return .hammer
        case .openInEditor: return .code
        case .openTerminal: return .terminal
        case .revealInFinder: return .folder
        case .copyPath: return .copy
        case .run: return .play
        case .gitActivity: return .branch
        case .codeStats: return .bars
        case .dependencies: return .box
        case .outdatedDependencies: return .arrowUpCircle
        case .unusedCode: return .scissors
        case .cacheSize: return .drive
        case .cleanCache, .cleanCacheConfirmed: return .trash
        case .readme: return .doc
        case .addNote: return .notePlus
        case .addTodo: return .checklist
        case .openNote: return .note
        }
    }

    /// Icon tile tint. Matches the QuickSearch action palette where they overlap.
    var tintHex: String {
        switch self {
        case .openInDevAtlas: return "5E5CE6"
        case .openInXcode: return "1C7CF4"
        case .openInEditor: return "8B5CF6"
        case .openTerminal: return "3A3A3C"
        case .revealInFinder: return "1E9BF0"
        case .copyPath: return "8E8E93"
        case .run: return "30B158"
        case .gitActivity: return "F05033"
        case .codeStats: return "0A84FF"
        case .dependencies: return "AF52DE"
        case .outdatedDependencies: return "FF9F0A"
        case .unusedCode: return "FF6482"
        case .cacheSize: return "64D2FF"
        case .cleanCache, .cleanCacheConfirmed: return "FF453A"
        case .readme: return "34C759"
        case .addNote: return "FFCC00"
        case .addTodo: return "FF9500"
        case .openNote: return "FFCC00"
        }
    }

    var isDestructive: Bool { self == .cleanCache || self == .cleanCacheConfirmed }

    var group: ChatActionGroup {
        switch self {
        case .openInDevAtlas, .openInXcode, .openInEditor, .openTerminal, .revealInFinder, .copyPath, .run:
            return .open
        case .gitActivity, .codeStats, .dependencies, .outdatedDependencies, .unusedCode, .readme:
            return .insights
        case .addNote, .addTodo, .openNote:
            return .notes
        case .cacheSize, .cleanCache, .cleanCacheConfirmed:
            return .cleanup
        }
    }

    /// Opens something outside the app (or copies) and returns at once.
    var isInstant: Bool {
        switch self {
        case .openInDevAtlas, .openInXcode, .openInEditor, .openTerminal, .revealInFinder,
             .copyPath, .run, .openNote:
            return true
        default:
            return false
        }
    }

    /// Lowercase words that also select this action when typed.
    var keywords: [String] {
        switch self {
        case .openInDevAtlas: return ["open", "devatlas", "detail", "detay", "aç"]
        case .openInXcode: return ["xcode"]
        case .openInEditor(_, let name): return [name.lowercased(), "editor", "code", "edit"]
        case .openTerminal: return ["terminal", "term", "shell", "uçbirim"]
        case .revealInFinder: return ["finder", "reveal", "folder", "klasör"]
        case .copyPath: return ["copy", "path", "kopyala", "yol"]
        case .run: return ["run", "start", "çalıştır", "başlat"]
        case .gitActivity: return ["git", "commits", "activity", "commit", "aktivite"]
        case .codeStats: return ["stats", "lines", "loc", "code", "istatistik", "satır"]
        case .dependencies: return ["deps", "dependencies", "packages", "bağımlılık", "paket"]
        case .outdatedDependencies: return ["outdated", "updates", "upgrade", "güncel", "güncelleme"]
        case .unusedCode: return ["unused", "dead", "periphery", "kullanılmayan"]
        case .cacheSize: return ["cache", "size", "önbellek", "boyut"]
        case .cleanCache, .cleanCacheConfirmed: return ["clean", "clear", "temizle"]
        case .readme: return ["readme", "docs", "belge"]
        case .addNote: return ["note", "not"]
        case .addTodo: return ["todo", "task", "görev", "yapılacak"]
        case .openNote: return []
        }
    }
}

enum ChatActionGroup: Int, CaseIterable {
    case open, insights, notes, cleanup

    var title: String {
        switch self {
        case .open: return "chat.group.open".localized
        case .insights: return "chat.group.insights".localized
        case .notes: return "chat.group.notes".localized
        case .cleanup: return "chat.group.cleanup".localized
        }
    }
}

enum ChatSlashCommand: String, CaseIterable, Identifiable, Codable {
    case recent, stats, rescan, new, help

    var id: String { rawValue }
    var token: String { "/" + rawValue }
    var title: String { "chat.command.\(rawValue)".localized }
    var glyph: ChatGlyph {
        switch self {
        case .recent: return .clock
        case .stats: return .pie
        case .rescan: return .refresh
        case .new: return .compose
        case .help: return .help
        }
    }
}

enum ChatPendingInput: Hashable {
    case noteText(projectID: String)
    case todoText(projectID: String)
}

/// One row of the list above the composer.
enum ChatSuggestion: Identifiable, Hashable {
    case project(ProjectInfo, matchedIndices: Set<Int>)
    case action(ChatAction, number: Int)
    case command(ChatSlashCommand)

    var id: String {
        switch self {
        case .project(let project, _): return "project:\(project.id)"
        case .action(let action, _): return "action:\(action.id)"
        case .command(let command): return "command:\(command.rawValue)"
        }
    }
}
