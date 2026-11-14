import SwiftUI
import AppKit

/// The Spotlight-style card shown by Control-Space: search projects, then choose what to do.
struct QuickSearchView: View {
    @Bindable var model: QuickSearchModel
    @FocusState private var isFieldFocused: Bool
    @State private var hoveredIndex: Int?

    static let cardWidth: CGFloat = 680
    /// Clear space between the panel's edges and the card, where the card's shadow falls.
    static let cardSideInset: CGFloat = 24
    static let cardTopInset: CGFloat = 12
    static let searchBarHeight: CGFloat = 62
    private static let cornerRadius: CGFloat = 24
    private static let projectRowHeight: CGFloat = 58
    private static let actionRowHeight: CGFloat = 48
    private static let maxListHeight: CGFloat = 380
    private static let rowSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            separator
            content
            separator
            footer
        }
        .frame(width: Self.cardWidth)
        .modifier(QuickSearchCardBackground(cornerRadius: Self.cornerRadius))
        .padding(.horizontal, Self.cardSideInset)
        .padding(.top, Self.cardTopInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { isFieldFocused = true }
        .onChange(of: model.focusRequest) { isFieldFocused = true }
        .onChange(of: model.stage) { hoveredIndex = nil }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            if case .actions(let project) = model.stage {
                Button {
                    model.backToProjects()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .adaptiveFont(size: 11, weight: .bold)
                        Text(project.name)
                            .adaptiveFont(size: 13, weight: .semibold)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                Image(systemName: "magnifyingglass")
                    .adaptiveFont(size: 21, weight: .medium)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            TextField(
                "",
                text: $model.query,
                prompt: Text(model.isShowingActions ? "quickSearch.actionsPlaceholder".localized : "quickSearch.placeholder".localized)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 22, weight: .regular))
            .focused($isFieldFocused)

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: Self.searchBarHeight)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.stage {
        case .projects:
            projectList
                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
        case .actions(let project):
            VStack(spacing: 0) {
                ProjectSummaryHeader(project: project)
                actionList
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)))
        }
    }

    private var projectList: some View {
        let matches = model.matches
        return VStack(alignment: .leading, spacing: 0) {
            if matches.isEmpty {
                emptyState(
                    systemImage: model.hasAnyProjects ? "magnifyingglass" : "folder.badge.questionmark",
                    text: model.hasAnyProjects ? "quickSearch.noResults".localized : "quickSearch.noProjectsYet".localized
                )
            } else {
                sectionTitle(model.isShowingRecent ? "quickSearch.recent".localized : "quickSearch.results".localized(matches.count))
                scrollingList(count: matches.count, rowHeight: Self.projectRowHeight) { index in
                    ProjectResultRow(match: matches[index], isSelected: index == model.selection, isHovered: index == hoveredIndex)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.selection = index
                            model.activateSelection()
                        }
                }
            }
        }
    }

    private var actionList: some View {
        let actions = model.actions
        return VStack(alignment: .leading, spacing: 0) {
            if actions.isEmpty {
                emptyState(systemImage: "bolt.slash", text: "quickSearch.noActions".localized)
            } else {
                sectionTitle("quickSearch.actions".localized)
                scrollingList(count: actions.count, rowHeight: Self.actionRowHeight) { index in
                    ActionRow(action: actions[index], number: index + 1, isSelected: index == model.selection, isHovered: index == hoveredIndex)
                        .contentShape(Rectangle())
                        .onTapGesture { model.perform(actions[index]) }
                }
            }
        }
    }

    private func scrollingList<Row: View>(count: Int, rowHeight: CGFloat, @ViewBuilder row: @escaping (Int) -> Row) -> some View {
        let height = min(CGFloat(count) * (rowHeight + Self.rowSpacing) + 10, Self.maxListHeight)
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: Self.rowSpacing) {
                    ForEach(0..<count, id: \.self) { index in
                        row(index)
                            .frame(height: rowHeight)
                            .id(index)
                            .onHover { hovering in
                                if hovering {
                                    hoveredIndex = index
                                } else if hoveredIndex == index {
                                    hoveredIndex = nil
                                }
                            }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
            .frame(height: height)
            .onChange(of: model.selection) {
                proxy.scrollTo(model.selection)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .adaptiveFont(size: 11, weight: .medium)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private func emptyState(systemImage: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text("DevAtlas")
                    .adaptiveFont(size: 11.5, weight: .semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            KeyHint(keys: ["↑", "↓"], label: "quickSearch.hint.navigate".localized)
            if model.isShowingActions {
                KeyHint(keys: ["↩"], label: "quickSearch.hint.run".localized)
                KeyHint(keys: ["esc"], label: "quickSearch.hint.back".localized)
            } else {
                KeyHint(keys: ["↩"], label: "quickSearch.hint.actions".localized)
                KeyHint(keys: ["⌘", "↩"], label: "quickSearch.hint.open".localized)
                KeyHint(keys: ["esc"], label: "quickSearch.hint.close".localized)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Color.primary.opacity(0.03))
    }
}

// MARK: - Rows

private struct ProjectResultRow: View {
    let match: QuickSearchMatch
    let isSelected: Bool
    let isHovered: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var project: ProjectInfo { match.project }

    var body: some View {
        HStack(spacing: 12) {
            ProjectFolderIcon(project: project, size: 34, isInteractive: false)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(highlightedName)
                    .font(.system(size: 14))
                    .lineLimit(1)
                Text((project.path as NSString).abbreviatingWithTildeInPath)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            KeyCap(text: "↩")
                .opacity(isSelected ? 1 : 0)
        }
        .padding(.horizontal, 14)
        // Fills the whole row, not just the text, so the highlight has room above and below.
        .frame(maxHeight: .infinity)
        .background(SelectionBackground(isSelected: isSelected, isHovered: isHovered))
    }

    /// The name with the typed characters emphasized.
    private var highlightedName: AttributedString {
        var result = AttributedString()
        for (index, character) in project.name.enumerated() {
            var piece = AttributedString(String(character))
            if match.matchedIndices.contains(index) {
                piece.font = .system(size: 14, weight: Font.Weight.semibold.adapted(to: colorScheme))
                piece.foregroundColor = .primary
            } else {
                let weight: Font.Weight = match.matchedIndices.isEmpty ? .medium : .regular
                piece.font = .system(size: 14, weight: weight.adapted(to: colorScheme))
            }
            result.append(piece)
        }
        return result
    }
}

private struct ActionRow: View {
    let action: QuickSearchAction
    let number: Int
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(action.tint.gradient)
                Image(systemName: action.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
            .shadow(color: action.tint.opacity(0.35), radius: 4, y: 2)

            Text(action.title)
                .font(.system(size: 13.5))
                .lineLimit(1)

            if let subtitle = action.subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            if number <= 9 {
                HStack(spacing: 3) {
                    KeyCap(text: "⌘")
                    KeyCap(text: "\(number)")
                }
                .opacity(isSelected ? 1 : 0.55)
            }
        }
        .padding(.horizontal, 14)
        // Fills the whole row, not just the text, so the highlight has room above and below.
        .frame(maxHeight: .infinity)
        .background(SelectionBackground(isSelected: isSelected, isHovered: isHovered))
    }
}

/// The chosen project, shown above its actions.
private struct ProjectSummaryHeader: View {
    let project: ProjectInfo

    var body: some View {
        HStack(spacing: 14) {
            ProjectFolderIcon(project: project, size: 52, isInteractive: false)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .adaptiveFont(size: 17, weight: .medium)
                    .lineLimit(1)
                Text((project.path as NSString).abbreviatingWithTildeInPath)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    TypePill(text: project.projectType, color: Color(hex: project.displayIconColor))
                    if let branch = project.gitBranch, !branch.isEmpty {
                        Label(branch, systemImage: "arrow.triangle.branch")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Label(project.lastModified.formatted(.relative(presentation: .named)), systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.025))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
        }
    }
}

// MARK: - Pieces

/// A soft neutral highlight: stronger for the keyboard selection, lighter under the pointer.
private struct SelectionBackground: View {
    let isSelected: Bool
    var isHovered: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(isSelected ? 0.08 : (isHovered ? 0.04 : 0)))
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct TypePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .adaptiveFont(size: 10.5, weight: .semibold)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

private struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .adaptiveFont(size: 10.5, weight: .semibold, design: .rounded)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 18)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }
}

private struct KeyHint: View {
    let keys: [String]
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { KeyCap(text: $0) }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Adaptive Weight

private extension Font.Weight {
    /// Dark text on the light card reads heavier than light text on the dark one,
    /// so light mode steps every emphasized weight down by one.
    func adapted(to colorScheme: ColorScheme) -> Font.Weight {
        guard colorScheme == .light else { return self }
        switch self {
        case .bold: return .semibold
        case .semibold: return .medium
        case .medium: return .regular
        default: return self
        }
    }
}

private struct AdaptiveFont: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight.adapted(to: colorScheme), design: design))
    }
}

private extension View {
    func adaptiveFont(size: CGFloat, weight: Font.Weight, design: Font.Design = .default) -> some View {
        modifier(AdaptiveFont(size: size, weight: weight, design: design))
    }
}

/// Liquid Glass where the system has it, a blurred panel elsewhere.
private struct QuickSearchCardBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
                .shadow(color: .black.opacity(0.22), radius: 28, y: 14)
        } else {
            content
                .background(VisualEffectBackground())
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 28, y: 14)
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        // The panel never activates the app, so the blur must not wait for it.
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
