import SwiftUI

/// Finder's icon view: click selects, double click opens, arrow keys move the selection.
struct ProjectIconGridView: View {
    @Bindable var viewModel: AppViewModel
    let iconSize: CGFloat

    @FocusState private var isFocused: Bool

    private let spacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 20
    private var tileWidth: CGFloat { iconSize + 44 }

    var body: some View {
        GeometryReader { proxy in
            let columnCount = columnCount(for: proxy.size.width)

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: columnCount),
                    spacing: 14,
                    pinnedViews: .sectionHeaders
                ) {
                    ForEach(viewModel.groupedFilteredProjects, id: \.0.id) { group, projects in
                        Section {
                            ForEach(projects) { project in
                                tile(for: project)
                            }
                        } header: {
                            sectionHeader(for: group, count: projects.count)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.highlightedProjectID = nil
                    isFocused = true
                }
            }
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .return]) { press in
                handleKey(press.key, columnCount: columnCount)
            }
        }
        .onAppear { isFocused = true }
    }

    private func columnCount(for width: CGFloat) -> Int {
        max(1, Int((width - horizontalPadding * 2 + spacing) / (tileWidth + spacing)))
    }

    private func tile(for project: ProjectInfo) -> some View {
        ProjectIconTile(
            project: project,
            iconSize: iconSize,
            isSelected: viewModel.highlightedProjectID == project.id,
            onSelect: {
                viewModel.highlightedProjectID = project.id
                isFocused = true
            },
            onOpen: { viewModel.selectProject(project) }
        )
        .frame(width: tileWidth)
        .contextMenu {
            ProjectContextMenu(viewModel: viewModel, project: project)
        }
    }

    private func sectionHeader(for group: ProjectTimelineGroup, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(group.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.daSecondaryText)
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundStyle(Color.daMutedText)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(alignment: .bottom) {
            Rectangle().fill(Color.daBorder).frame(height: 0.5)
        }
        .padding(.top, 4)
    }

    // MARK: - Keyboard

    private func handleKey(_ key: KeyEquivalent, columnCount: Int) -> KeyPress.Result {
        let rows = viewModel.groupedFilteredProjects.flatMap { _, projects in
            projects.chunked(into: columnCount)
        }
        guard let first = rows.first?.first else { return .ignored }

        guard let selectedID = viewModel.highlightedProjectID,
              let row = rows.firstIndex(where: { $0.contains { $0.id == selectedID } }),
              let column = rows[row].firstIndex(where: { $0.id == selectedID }) else {
            guard key != .return else { return .ignored }
            viewModel.highlightedProjectID = first.id
            return .handled
        }

        switch key {
        case .return:
            viewModel.selectProject(rows[row][column])
        case .leftArrow:
            if column > 0 {
                viewModel.highlightedProjectID = rows[row][column - 1].id
            } else if row > 0, let previous = rows[row - 1].last {
                viewModel.highlightedProjectID = previous.id
            }
        case .rightArrow:
            if column + 1 < rows[row].count {
                viewModel.highlightedProjectID = rows[row][column + 1].id
            } else if row + 1 < rows.count {
                viewModel.highlightedProjectID = rows[row + 1][0].id
            }
        case .upArrow where row > 0:
            viewModel.highlightedProjectID = rows[row - 1][min(column, rows[row - 1].count - 1)].id
        case .downArrow where row + 1 < rows.count:
            viewModel.highlightedProjectID = rows[row + 1][min(column, rows[row + 1].count - 1)].id
        default:
            break
        }
        return .handled
    }
}

private struct ProjectIconTile: View {
    let project: ProjectInfo
    let iconSize: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    @State private var rippleCount = 0

    var body: some View {
        VStack(spacing: 5) {
            ProjectFolderIcon(project: project, size: iconSize)
                .daRipple(origin: CGPoint(x: iconSize / 2, y: iconSize * 0.44), trigger: rippleCount)
                .padding(7)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.daAccent.opacity(0.10))
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.daAccent.opacity(0.55), lineWidth: 1)
                    }
                }

            Text(project.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.daPrimaryText)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.daAccent)
                    }
                }

            Text(project.projectType)
                .font(.system(size: 10))
                .foregroundStyle(Color.daMutedText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onOpen)
        .simultaneousGesture(
            TapGesture().onEnded {
                if !isSelected { rippleCount += 1 }
                onSelect()
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: "finder.open".localized, onOpen)
    }
}
