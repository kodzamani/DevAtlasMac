import SwiftUI
import Charts
import AppKit

// Rich result cards the assistant shows after running an action.
// Each card is self-contained: it takes its payload and owns only transient UI state
// (hover, expanded sections, copy feedback).

// MARK: - Shared pieces

/// The card container every result uses.
struct ChatResultCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chatSurface(cornerRadius: ChatMetrics.cardCorner)
    }
}

/// Card title in the style of OverviewCardHeading, with an optional subtitle.
struct ChatResultHeading: View {
    let title: String
    let glyph: ChatGlyph
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ChatIconLabel(title: title, glyph: glyph, iconSize: 13, spacing: 6)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.daPrimaryText)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daTertiaryText)
                    .lineLimit(1)
            }
        }
    }
}

/// Small uppercase label above a group of rows.
struct ChatResultSectionLabel: View {
    let text: String
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .textCase(.uppercase)
            if let count {
                Text(count.formatted())
                    .monospacedDigit()
                    .foregroundStyle(Color.daMutedText)
            }
        }
        .font(.system(size: 10.5, weight: .semibold))
        .tracking(0.3)
        .foregroundStyle(Color.daTertiaryText)
        .lineLimit(1)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A thin horizontal bar filled to `fraction` (0...1) of its width.
struct ChatProportionBar: View {
    let fraction: Double
    var color: Color = .daAccent
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.06))
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(height, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A strip of figures sharing one tinted surface.
struct ChatStatStrip: View {
    let items: [(label: String, value: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { StatStripDivider() }
                StatMiniCard(label: item.label, value: item.value)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }
}

/// Row button with a soft hover highlight.
struct ChatHoverRowStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, cornerRadius: cornerRadius)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let cornerRadius: CGFloat
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : (isHovered ? 0.045 : 0)))
                )
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .onHover { isHovered = $0 }
        }
    }
}

/// Inline "Show all (N)" / "Show less" toggle.
struct ChatShowAllButton: View {
    let total: Int
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "chat.card.showLess".localized : "chat.card.showAll".localized(total))
                ChatIcon(.chevronDown, size: 10.5)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Color.daAccent)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
    }
}

/// Shows the first `limit` items, then a toggle that reveals the rest.
struct ChatExpandableList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var limit: Int = 8
    var spacing: CGFloat = 6
    @ViewBuilder let row: (Item) -> Row

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(isExpanded ? items : Array(items.prefix(limit))) { item in
                row(item)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if items.count > limit {
                ChatShowAllButton(total: items.count, isExpanded: $isExpanded)
                    .padding(.top, 2)
            }
        }
    }
}

/// A one-line status (success / warning) inside a card.
struct ChatInlineStatus: View {
    let glyph: ChatGlyph
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ChatIcon(glyph, size: 13)
                .foregroundStyle(color)
            Text(text)
                .foregroundStyle(Color.daSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12, weight: .medium))
    }
}

/// Empty / not-available state, as in the project overview cards.
struct ChatCardEmptyState: View {
    let glyph: ChatGlyph
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ChatIcon(glyph, size: 18, weight: 1.2)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.daTertiaryText)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Small capsule with an icon and a short value (branch, hash, counts).
struct ChatInfoPill: View {
    var glyph: ChatGlyph? = nil
    let text: String
    var color: Color = .daSecondaryText
    var monospaced: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let glyph {
                ChatIcon(glyph, size: 11)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium, design: monospaced ? .monospaced : .default))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}

enum ChatRelativeDate {
    static func string(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.english.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Git

struct ChatGitCard: View {
    let payload: ChatGitPayload

    @State private var hoveredDate: Date?

    var body: some View {
        ChatResultCard {
            HStack(alignment: .top) {
                ChatResultHeading(
                    title: "chat.card.git.title".localized,
                    glyph: .branch,
                    subtitle: payload.isRepository ? "chat.card.git.subtitle".localized(payload.rangeDays) : nil
                )
                Spacer(minLength: 8)
                if let remote = payload.remoteURL, payload.isRepository {
                    Link(destination: remote) {
                        ChatIconLabel(title: "detail.git.openRemote".localized, glyph: .external)
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(Color.daAccent)
                    .help(remote.absoluteString)
                    .cursor(.pointingHand)
                }
            }

            if payload.isRepository {
                repositoryContent
            } else {
                ChatCardEmptyState(glyph: .branch, message: "detail.git.noRepository".localized)
            }
        }
    }

    @ViewBuilder
    private var repositoryContent: some View {
        FlowLayout(spacing: 6) {
            ChatInfoPill(
                glyph: .branch,
                text: payload.branch ?? "detail.git.detached".localized,
                color: .daAccent
            )
            if payload.changedFiles == 0 {
                ChatInfoPill(glyph: .check, text: "detail.git.clean".localized, color: .daGreen)
            } else {
                ChatInfoPill(glyph: .pencil, text: "detail.git.changedFiles".localized(payload.changedFiles), color: .daOrange)
            }
        }

        lastCommit

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ChatResultSectionLabel(text: "chat.card.git.commitsPerDay".localized)
                Spacer()
                if let day = hoveredDay {
                    Text("\(day.date.formatted(.dateTime.month(.abbreviated).day())) · \(day.commits.formatted()) \("chat.card.git.commits".localized)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.daSecondaryText)
                        .transition(.opacity)
                }
            }
            if payload.totalCommits == 0 {
                ChatCardEmptyState(glyph: .bars, message: "chat.card.git.noActivity".localized)
            } else {
                chart
            }
        }
        .animation(.easeOut(duration: 0.12), value: hoveredDay?.date)

        totals
    }

    @ViewBuilder
    private var lastCommit: some View {
        VStack(alignment: .leading, spacing: 5) {
            ChatResultSectionLabel(text: "detail.git.lastCommit".localized)
            if let subject = payload.lastCommitSubject {
                Text(subject)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.daPrimaryText)
                    .lineLimit(2)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    if let hash = payload.lastCommitHash {
                        Text(String(hash.prefix(7)))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.daSecondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.06)))
                            .textSelection(.enabled)
                    }
                    if let date = payload.lastCommitDate {
                        ChatIconLabel(title: ChatRelativeDate.string(for: date), glyph: .clock)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.daTertiaryText)
                    }
                }
            } else {
                Text("detail.git.noCommits".localized)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daTertiaryText)
            }
        }
    }

    private var hoveredDay: ChatGitPayload.Day? {
        guard let hoveredDate else { return nil }
        return payload.days.first { Calendar.current.isDate($0.date, inSameDayAs: hoveredDate) }
    }

    private var chart: some View {
        Chart(payload.days) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Commits", day.commits)
            )
            .cornerRadius(3)
            .foregroundStyle(Color.daAccent.gradient)
            .opacity(hoveredDay == nil || hoveredDay?.date == day.date ? 1 : 0.4)
        }
        .chartXSelection(value: $hoveredDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.primary.opacity(0.12))
                AxisValueLabel()
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.daMutedText)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.daMutedText)
            }
        }
        .frame(height: 90)
        .accessibilityLabel("chat.card.git.commitsPerDay".localized)
    }

    private var totals: some View {
        HStack(spacing: 18) {
            totalItem(value: payload.totalCommits.formatted(), label: "chat.card.git.commits".localized, color: .daPrimaryText)
            totalItem(value: "+" + payload.totalAdditions.formatted(), label: "chat.card.git.additions".localized, color: .daGreen)
            totalItem(value: "−" + payload.totalDeletions.formatted(), label: "chat.card.git.deletions".localized, color: .red)
            Spacer(minLength: 0)
        }
    }

    private func totalItem(value: String, label: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.daTertiaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Code stats

struct ChatCodeStatsCard: View {
    let payload: ChatCodeStatsPayload

    var body: some View {
        ChatResultCard {
            ChatResultHeading(title: "chat.card.codeStats.title".localized, glyph: .bars)

            ChatStatStrip(items: [
                ("chat.card.codeStats.files".localized, payload.totalFiles.formatted()),
                ("chat.card.codeStats.lines".localized, payload.totalLines.formatted()),
                ("chat.card.codeStats.size".localized, payload.sizeOnDisk)
            ])

            if !payload.languages.isEmpty {
                languages
            }

            if !payload.largestFiles.isEmpty {
                largestFiles
            }
        }
    }

    private var languages: some View {
        VStack(alignment: .leading, spacing: 9) {
            ChatResultSectionLabel(text: "detail.languages.title".localized)

            Canvas { context, size in
                let total = payload.languages.reduce(0) { $0 + $1.percentage }
                guard total > 0 else { return }
                let gap: CGFloat = payload.languages.count > 1 ? 2 : 0
                let usable = size.width - gap * CGFloat(payload.languages.count - 1)
                var x: CGFloat = 0
                for language in payload.languages {
                    let width = max(0, usable * language.percentage / total)
                    let rect = CGRect(x: x, y: 0, width: width, height: size.height)
                    context.fill(Path(rect), with: .color(Color(hex: language.colorHex)))
                    x += width + gap
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
            .accessibilityHidden(true)

            FlowLayout(spacing: 12) {
                ForEach(payload.languages) { language in
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: language.colorHex)).frame(width: 7, height: 7)
                        Text(language.name)
                            .foregroundStyle(Color.daSecondaryText)
                        Text(language.percentage / 100, format: .percent.precision(.fractionLength(1)))
                            .monospacedDigit()
                            .foregroundStyle(Color.daTertiaryText)
                    }
                    .font(.system(size: 11))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var largestFiles: some View {
        let maxLines = max(payload.largestFiles.map(\.lines).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            ChatResultSectionLabel(text: "chat.card.codeStats.largestFiles".localized)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(payload.largestFiles) { file in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(file.path)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(Color.daSecondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(file.path)
                            Spacer(minLength: 8)
                            Text(file.lines.formatted())
                                .font(.system(size: 11.5, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(Color.daTertiaryText)
                        }
                        ChatProportionBar(fraction: Double(file.lines) / Double(maxLines), color: .daAccent.opacity(0.7), height: 3)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Dependencies

struct ChatDependenciesCard: View {
    let payload: ChatDependenciesPayload

    private struct DependencySection: Identifiable {
        let id: String
        let title: String
        let items: [Dependency]
    }

    var body: some View {
        ChatResultCard {
            ChatResultHeading(title: "chat.card.dependencies.title".localized, glyph: .box)

            if payload.all.isEmpty {
                ChatCardEmptyState(glyph: .box, message: "chat.card.dependencies.empty".localized)
            } else {
                counts

                if payload.checkedLatest && payload.outdated.isEmpty {
                    ChatInlineStatus(glyph: .checkCircle, text: "chat.card.dependencies.upToDate".localized, color: .daGreen)
                }

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 7) {
                        ChatResultSectionLabel(text: section.title, count: section.items.count)
                        ChatExpandableList(items: section.items, limit: 8, spacing: 2) { dependency in
                            row(dependency)
                        }
                    }
                }
            }
        }
    }

    private var counts: some View {
        FlowLayout(spacing: 6) {
            if !payload.direct.isEmpty {
                ChatInfoPill(text: "chat.card.dependencies.directCount".localized(payload.direct.count))
            }
            if !payload.dev.isEmpty {
                ChatInfoPill(text: "chat.card.dependencies.devCount".localized(payload.dev.count))
            }
            if !payload.grouped.isEmpty {
                ChatInfoPill(text: "chat.card.dependencies.totalCount".localized(payload.all.count))
            }
            if payload.checkedLatest && !payload.outdated.isEmpty {
                ChatInfoPill(glyph: .arrowUpCircle, text: "chat.card.dependencies.outdatedCount".localized(payload.outdated.count), color: .daOrange)
            }
        }
    }

    private var sections: [DependencySection] {
        var result: [DependencySection] = []
        if !payload.direct.isEmpty {
            result.append(DependencySection(id: "direct", title: "chat.card.dependencies.direct".localized, items: ordered(payload.direct)))
        }
        if !payload.dev.isEmpty {
            result.append(DependencySection(id: "dev", title: "chat.card.dependencies.dev".localized, items: ordered(payload.dev)))
        }
        for key in payload.grouped.keys.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
            let items = payload.grouped[key] ?? []
            guard !items.isEmpty else { continue }
            result.append(DependencySection(id: "group:\(key)", title: key, items: ordered(items)))
        }
        return result
    }

    /// Outdated packages first so they are visible without expanding.
    private func ordered(_ items: [Dependency]) -> [Dependency] {
        guard payload.checkedLatest else { return items }
        return items.filter(\.isUpgradeable) + items.filter { !$0.isUpgradeable }
    }

    private func row(_ dependency: Dependency) -> some View {
        HStack(spacing: 8) {
            Text(dependency.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.daPrimaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 8)
            if dependency.isUpgradeable, let latest = dependency.latestVersion {
                Text("\(dependency.displayVersion) → \(latest)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.daOrange)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.daOrange.opacity(0.14)))
            } else {
                Text(dependency.displayVersion)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.daTertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Unused code

struct ChatUnusedCodeCard: View {
    let payload: ChatUnusedCodePayload

    @State private var didCopy = false

    private struct KindGroup: Identifiable {
        var id: String { kind }
        let kind: String
        let items: [ChatUnusedCodePayload.Item]
    }

    var body: some View {
        ChatResultCard {
            HStack(alignment: .top) {
                ChatResultHeading(
                    title: "chat.card.unusedCode.title".localized,
                    glyph: .scissors,
                    subtitle: payload.totalCount > 0 ? "chat.card.unusedCode.count".localized(payload.totalCount) : nil
                )
                Spacer(minLength: 8)
                if let prompt = payload.removalPrompt, payload.totalCount > 0 {
                    copyButton(prompt)
                }
            }

            if payload.totalCount == 0 {
                ChatInlineStatus(glyph: .checkCircle, text: "chat.card.unusedCode.none".localized, color: .daGreen)
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 7) {
                        ChatResultSectionLabel(text: group.kind, count: group.items.count)
                        ChatExpandableList(items: group.items, limit: 10, spacing: 6) { item in
                            row(item)
                        }
                    }
                }
                if payload.items.count < payload.totalCount {
                    Text("chat.card.unusedCode.showingFirst".localized(payload.items.count))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.daTertiaryText)
                }
            }
        }
    }

    private var groups: [KindGroup] {
        Dictionary(grouping: payload.items, by: \.kind)
            .map { KindGroup(kind: $0.key, items: $0.value) }
            .sorted { $0.items.count != $1.items.count ? $0.items.count > $1.items.count : $0.kind < $1.kind }
    }

    private func row(_ item: ChatUnusedCodePayload.Item) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.name)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.daPrimaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Text(item.location)
                .font(.system(size: 11))
                .foregroundStyle(Color.daTertiaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(item.location)
        }
        .accessibilityElement(children: .combine)
    }

    private func copyButton(_ prompt: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
            withAnimation(.easeOut(duration: 0.12)) { didCopy = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeOut(duration: 0.2)) { didCopy = false }
            }
        } label: {
            ChatIconLabel(
                title: didCopy ? "chat.card.unusedCode.copied".localized : "chat.card.unusedCode.copyPrompt".localized,
                glyph: didCopy ? .check : .copy
            )
        }
        .buttonStyle(ChatChipButtonStyle(tint: didCopy ? .daGreen : .daAccent))
        .cursor(.pointingHand)
    }
}

// MARK: - Cache

struct ChatCacheCard: View {
    let payload: ChatCachePayload

    private var sortedFolders: [ChatCachePayload.Folder] {
        payload.folders.sorted { $0.bytes > $1.bytes }
    }

    var body: some View {
        ChatResultCard {
            if let freed = payload.freedBytes {
                HStack(spacing: 12) {
                    ChatIcon(.checkCircle, size: 27.5)
                        .foregroundStyle(Color.daGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("cache.result.freed".localized(freed.chatByteString))
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.daPrimaryText)
                        Text("chat.card.cache.cleaned".localized)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.daTertiaryText)
                    }
                }
                if payload.failedCount > 0 {
                    ChatInlineStatus(glyph: .warning, text: "cache.result.failed".localized(payload.failedCount), color: .daOrange)
                }
            } else {
                HStack(alignment: .top) {
                    ChatResultHeading(title: "chat.card.cache.title".localized, glyph: .drive)
                    Spacer(minLength: 8)
                    if !payload.folders.isEmpty {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(payload.totalBytes.chatByteString)
                                .font(.system(size: 20, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.daPrimaryText)
                            Text("cache.reclaimable".localized)
                                .font(.system(size: 10.5, weight: .medium))
                                .textCase(.uppercase)
                                .foregroundStyle(Color.daTertiaryText)
                        }
                    }
                }
                if payload.folders.isEmpty {
                    ChatInlineStatus(glyph: .sparkles, text: "cache.empty.message".localized, color: .daGreen)
                }
            }

            if !payload.folders.isEmpty {
                folderList
            }
        }
    }

    private var folderList: some View {
        let maxBytes = max(sortedFolders.first?.bytes ?? 1, 1)
        return VStack(alignment: .leading, spacing: 6) {
            ChatResultSectionLabel(text: "cache.folderCount".localized(payload.folders.count))
            VStack(spacing: 2) {
                ForEach(sortedFolders) { folder in
                    folderRow(folder, fraction: Double(folder.bytes) / Double(maxBytes))
                }
            }
            .padding(.horizontal, -6)
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: ChatCachePayload.Folder, fraction: Double) -> some View {
        let content = HStack(spacing: 10) {
            ChatIconTile(glyph: Self.icon(for: folder.kindTitleKey), tint: Color(hex: "64D2FF"), size: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(folder.displayName)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.daPrimaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(folder.kindTitleKey.localized)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.daTertiaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(folder.bytes.chatByteString)
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.daSecondaryText)
                }
                ChatProportionBar(fraction: fraction, color: payload.freedBytes == nil ? Color(hex: "64D2FF") : .daGreen, height: 3)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)

        if payload.freedBytes == nil {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder.path)])
            } label: {
                content
            }
            .buttonStyle(ChatHoverRowStyle())
            .help(folder.path)
        } else {
            content
        }
    }

    static func icon(for kindKey: String) -> ChatGlyph {
        switch kindKey {
        case "cache.kind.nodeModules": return .box
        case "cache.kind.derivedData": return .hammer
        case "cache.kind.buildOutput": return .box
        case "cache.kind.packages": return .box
        case "cache.kind.frameworkCache": return .sparkles
        case "cache.kind.toolCache": return .hammer
        case "cache.kind.virtualEnv": return .folder
        default: return .folder
        }
    }
}

// MARK: - Readme

struct ChatReadmeCard: View {
    let payload: ChatReadmePayload

    @State private var isExpanded = false
    @State private var contentHeight: CGFloat = 0

    private let collapsedHeight: CGFloat = 320
    private var isClipped: Bool { contentHeight > collapsedHeight + 24 }

    var body: some View {
        ChatResultCard {
            HStack(alignment: .center) {
                ChatResultHeading(title: payload.fileURL.lastPathComponent, glyph: .doc)
                Spacer(minLength: 8)
                Button {
                    NSWorkspace.shared.open(payload.fileURL)
                } label: {
                    ChatIconLabel(title: "detail.readme.openFile".localized, glyph: .external)
                }
                .buttonStyle(ChatChipButtonStyle(tint: .daAccent))
                .cursor(.pointingHand)
            }

            if payload.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ChatCardEmptyState(glyph: .doc, message: "detail.readme.empty".localized)
            } else {
                preview

                if isClipped || payload.isTruncated {
                    HStack {
                        if isClipped {
                            Button {
                                withAnimation(.snappy(duration: 0.28)) { isExpanded.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(isExpanded ? "chat.card.readme.collapse".localized : "chat.card.readme.expand".localized)
                                    ChatIcon(.chevronDown, size: 10.5)
                                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                }
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Color.daAccent)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .cursor(.pointingHand)
                        }
                        Spacer(minLength: 8)
                        if payload.isTruncated && (isExpanded || !isClipped) {
                            Text("chat.card.readme.truncated".localized)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.daTertiaryText)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }

    private var preview: some View {
        previewContent
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ChatReadmeHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ChatReadmeHeightKey.self) { contentHeight = $0 }
            .frame(height: isClipped && !isExpanded ? collapsedHeight : nil, alignment: .top)
            .clipped()
            .mask {
                if isClipped && !isExpanded {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.72),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Rectangle()
                }
            }
    }

    @ViewBuilder
    private var previewContent: some View {
        if payload.isMarkdown {
            CustomMarkdownView(content: payload.preview)
                .padding(.horizontal, -10)
                .padding(.bottom, -10)
        } else {
            Text(payload.preview)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Color.daSecondaryText)
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ChatReadmeHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Workspace stats

struct ChatWorkspaceStatsCard: View {
    let payload: ChatWorkspaceStatsPayload

    var body: some View {
        ChatResultCard {
            ChatResultHeading(title: "chat.card.workspace.title".localized, glyph: .pie)

            ChatStatStrip(items: [
                ("chat.card.workspace.projects".localized, payload.projectCount.formatted()),
                ("chat.card.codeStats.files".localized, payload.totalFiles.formatted()),
                ("chat.card.codeStats.lines".localized, payload.totalLines.formatted())
            ])

            if !payload.byCategory.isEmpty {
                bars(title: "chat.card.workspace.byCategory".localized, slices: payload.byCategory)
            }
            if !payload.byLanguage.isEmpty {
                bars(title: "chat.card.workspace.byLanguage".localized, slices: payload.byLanguage)
            }
        }
    }

    private func bars(title: String, slices: [ChatWorkspaceStatsPayload.Slice]) -> some View {
        let maxCount = max(slices.map(\.count).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            ChatResultSectionLabel(text: title)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 7) {
                ForEach(slices) { slice in
                    GridRow {
                        HStack(spacing: 6) {
                            if let hex = slice.colorHex {
                                Circle().fill(Color(hex: hex)).frame(width: 7, height: 7)
                            }
                            Text(slice.name)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.daSecondaryText)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 90, alignment: .leading)
                        ChatProportionBar(
                            fraction: Double(slice.count) / Double(maxCount),
                            color: slice.colorHex.map { Color(hex: $0) } ?? .daAccent,
                            height: 6
                        )
                        Text(slice.count.formatted())
                            .font(.system(size: 11.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Color.daTertiaryText)
                            .gridColumnAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
private enum ChatCardPreviewData {
    static let git: ChatGitPayload = {
        let today = Calendar.current.startOfDay(for: Date())
        let days = (0..<30).map { offset -> ChatGitPayload.Day in
            let date = Calendar.current.date(byAdding: .day, value: offset - 29, to: today)!
            let commits = [0, 1, 3, 0, 2, 5, 1, 0, 4][offset % 9]
            return .init(date: date, additions: commits * 42, deletions: commits * 11, commits: commits)
        }
        return ChatGitPayload(
            isRepository: true, branch: "main", changedFiles: 3,
            lastCommitHash: "bad6890c1f", lastCommitSubject: "Add project cache cleanup",
            lastCommitDate: Date().addingTimeInterval(-7200),
            remoteURL: URL(string: "https://github.com/example/devatlas"),
            rangeDays: 30, days: days
        )
    }()

    static let code = ChatCodeStatsPayload(
        totalFiles: 214, totalLines: 38_412, sizeOnDisk: "4.2 MB",
        languages: [
            .init(name: "Swift", percentage: 82.4, colorHex: "FA7343"),
            .init(name: "Metal", percentage: 9.1, colorHex: "8B5CF6"),
            .init(name: "JSON", percentage: 8.5, colorHex: "94A3B8")
        ],
        largestFiles: [
            .init(path: "DevAtlasMac/Views/Notebook/NoteEditorView.swift", lines: 1_240),
            .init(path: "DevAtlasMac/Views/Stats/StatsContentView.swift", lines: 980),
            .init(path: "DevAtlasMac/ViewModels/AppViewModel.swift", lines: 512)
        ]
    )

    static let deps = ChatDependenciesPayload(
        direct: (1...11).map {
            Dependency(name: "package-\($0)", version: "1.\($0).0", type: .regular, source: .npm,
                       latestVersion: $0 % 4 == 0 ? "2.0.0" : "1.\($0).0")
        },
        dev: [Dependency(name: "typescript", version: "5.4.2", type: .dev, source: .npm, latestVersion: "5.4.2")],
        grouped: [:],
        checkedLatest: true
    )

    static let unused = ChatUnusedCodePayload(
        items: [
            .init(kind: "Function", name: "legacyFormatter()", location: "Utils/Format.swift:42"),
            .init(kind: "Function", name: "debugDump(_:)", location: "Utils/Debug.swift:12"),
            .init(kind: "Property", name: "oldCache", location: "Services/Cache.swift:8")
        ],
        totalCount: 3,
        removalPrompt: "Remove the following unused declarations…"
    )

    static let cache = ChatCachePayload(folders: [
        .init(path: "/tmp/a/node_modules", displayName: "node_modules", kindTitleKey: "cache.kind.nodeModules", bytes: 812_000_000),
        .init(path: "/tmp/a/.build", displayName: ".build", kindTitleKey: "cache.kind.buildOutput", bytes: 210_000_000)
    ])

    static let readme = ChatReadmePayload(
        fileURL: URL(fileURLWithPath: "/tmp/README.md"),
        preview: "# DevAtlas\n\nA developer dashboard for macOS.\n\n" + String(repeating: "- Feature line with some text\n", count: 30),
        isMarkdown: true, isTruncated: true
    )

    static let workspace = ChatWorkspaceStatsPayload(
        projectCount: 42, totalFiles: 18_300, totalLines: 1_204_000,
        byCategory: [.init(name: "Mobile", count: 18), .init(name: "Web", count: 14), .init(name: "Desktop", count: 7)],
        byLanguage: [.init(name: "Swift", count: 20, colorHex: "FA7343"), .init(name: "TypeScript", count: 12, colorHex: "3178C6")]
    )
}

#Preview("Result cards") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ChatGitCard(payload: ChatCardPreviewData.git)
            ChatCodeStatsCard(payload: ChatCardPreviewData.code)
            ChatDependenciesCard(payload: ChatCardPreviewData.deps)
            ChatUnusedCodeCard(payload: ChatCardPreviewData.unused)
            ChatCacheCard(payload: ChatCardPreviewData.cache)
            ChatReadmeCard(payload: ChatCardPreviewData.readme)
            ChatWorkspaceStatsCard(payload: ChatCardPreviewData.workspace)
        }
        .frame(maxWidth: ChatMetrics.columnWidth - 40)
        .padding(24)
    }
    .frame(width: 760, height: 900)
}
#endif
