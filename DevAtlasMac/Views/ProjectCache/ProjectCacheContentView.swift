import SwiftUI
import AppKit

/// Lists the regenerable folders of every project (installed packages, build output, tool
/// caches) and frees the space they take.
struct ProjectCacheContentView: View {
    @Bindable var viewModel: AppViewModel
    @Bindable var cacheVM: ProjectCacheViewModel

    @State private var isConfirmingClean = false

    private var visibleGroups: [ProjectCacheGroup] {
        cacheVM.visibleGroups(matching: viewModel.searchText)
    }

    var body: some View {
        let groups = visibleGroups

        VStack(spacing: 0) {
            if cacheVM.isScanning {
                CacheScanStrip(scanned: cacheVM.scannedProjects, total: cacheVM.totalProjects)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if cacheVM.hasScanned, !cacheVM.isScanning, cacheVM.groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryStrip
                        if !cacheVM.groups.isEmpty {
                            kindFilters
                        }
                        listCard(groups)
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if cacheVM.isCleaning || cacheVM.selectedCount > 0 || cacheVM.lastResult != nil {
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: cacheVM.isScanning)
        .animation(.easeInOut(duration: 0.2), value: cacheVM.selectedCount > 0)
        .animation(.easeInOut(duration: 0.2), value: cacheVM.lastResult)
        .task(id: viewModel.projects.isEmpty) {
            cacheVM.scanIfNeeded(viewModel.projects)
        }
        .confirmationDialog(
            "cache.confirm.title".localized(Self.formatted(cacheVM.selectedSize)),
            isPresented: $isConfirmingClean,
            titleVisibility: .visible
        ) {
            Button("cache.confirm.trash".localized) {
                cacheVM.cleanSelection(toTrash: true)
            }
            Button("cache.confirm.delete".localized, role: .destructive) {
                cacheVM.cleanSelection(toTrash: false)
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("cache.confirm.message".localized(cacheVM.selectedCount))
        }
    }

    // MARK: - Summary

    private var summaryStrip: some View {
        // Figures fill in as projects are measured; before the first one there is nothing to show.
        let hasFigures = !cacheVM.isScanning || !cacheVM.groups.isEmpty
        let largest = cacheVM.largestGroup

        return HStack(spacing: 0) {
            StatMiniCard(
                label: "cache.reclaimable".localized,
                value: hasFigures ? Self.formatted(cacheVM.totalSize) : nil
            )
            StatStripDivider()
            StatMiniCard(
                label: "cache.projects".localized,
                value: hasFigures ? cacheVM.groups.count.formatted() : nil
            )
            StatStripDivider()
            StatMiniCard(
                label: "cache.folders".localized,
                value: hasFigures ? cacheVM.folderCount.formatted() : nil
            )
            StatStripDivider()
            StatMiniCard(
                label: "cache.largest".localized,
                value: hasFigures ? (largest.map { Self.formatted($0.totalSize) } ?? "—") : nil,
                footnote: largest?.project.name
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .daCardSurface()
    }

    // MARK: - Kind Filters

    private var kindFilters: some View {
        FlowLayout(spacing: 8) {
            CacheFilterChip(
                title: "cache.filter.all".localized,
                size: Self.formatted(cacheVM.totalSize),
                isSelected: cacheVM.kindFilter == nil
            ) {
                cacheVM.kindFilter = nil
            }

            ForEach(cacheVM.sizeByKind, id: \.kind) { entry in
                CacheFilterChip(
                    title: entry.kind.titleKey.localized,
                    size: Self.formatted(entry.size),
                    isSelected: cacheVM.kindFilter == entry.kind
                ) {
                    cacheVM.kindFilter = cacheVM.kindFilter == entry.kind ? nil : entry.kind
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - List

    private func listCard(_ groups: [ProjectCacheGroup]) -> some View {
        let largestSize = groups.map(\.totalSize).max() ?? 0

        return VStack(spacing: 0) {
            listHeader(groups)

            if groups.isEmpty {
                if cacheVM.isScanning {
                    skeletonRows
                } else {
                    Text("cache.noMatches".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.daTertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(groups) { group in
                        Divider().opacity(0.6)

                        CacheProjectRow(
                            group: group,
                            fraction: largestSize > 0 ? Double(group.totalSize) / Double(largestSize) : 0,
                            isExpanded: cacheVM.expanded.contains(group.id),
                            selectionState: cacheVM.selectionState(of: group.items),
                            isDisabled: cacheVM.isCleaning,
                            onToggleSelection: { cacheVM.toggle(group.items) },
                            onToggleExpansion: {
                                withAnimation(.easeInOut(duration: 0.15)) { cacheVM.toggleExpansion(of: group) }
                            }
                        )

                        if cacheVM.expanded.contains(group.id) {
                            ForEach(group.items) { item in
                                CacheItemRow(
                                    item: item,
                                    isSelected: cacheVM.isSelected(item),
                                    isDisabled: cacheVM.isCleaning,
                                    onToggle: { cacheVM.toggle(item) }
                                )
                            }
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .daCardSurface()
    }

    private func listHeader(_ groups: [ProjectCacheGroup]) -> some View {
        let items = groups.flatMap(\.items)

        return HStack(spacing: 10) {
            CacheCheckbox(
                state: items.isEmpty ? .none : cacheVM.selectionState(of: items),
                label: "cache.select.all".localized
            ) {
                cacheVM.toggle(items)
            }
            .disabled(items.isEmpty || cacheVM.isCleaning)

            Menu("cache.select".localized) {
                Button("cache.select.all".localized) { cacheVM.select(groups) }
                Button("cache.select.none".localized) { cacheVM.selection = [] }
                Divider()
                Button("cache.select.stale30".localized) { cacheVM.select(groups, untouchedForDays: 30) }
                Button("cache.select.stale180".localized) { cacheVM.select(groups, untouchedForDays: 180) }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(items.isEmpty || cacheVM.isCleaning)

            Spacer()

            Picker("cache.sort".localized, selection: $cacheVM.sort) {
                ForEach(CacheSortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    private var skeletonRows: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { _ in
                Divider().opacity(0.6)
                HStack(spacing: 10) {
                    SkeletonBlock().frame(width: 24, height: 22)
                    SkeletonBlock().frame(width: 180, height: 12)
                    Spacer()
                    SkeletonBlock().frame(width: 60, height: 12)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.daTertiaryText)
                .accessibilityHidden(true)

            Text("cache.empty.title".localized)
                .font(.daSectionTitle)
                .foregroundStyle(Color.daPrimaryText)

            Text("cache.empty.message".localized)
                .font(.system(size: 12))
                .foregroundStyle(Color.daTertiaryText)
                .multilineTextAlignment(.center)

            Button("cache.rescan".localized) {
                cacheVM.scan(viewModel.projects)
            }
            .padding(.top, 6)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            if cacheVM.isCleaning {
                ProgressView().controlSize(.small)
                Text("cache.cleaning".localized)
                    .foregroundStyle(Color.daSecondaryText)
                Spacer()
            } else if cacheVM.selectedCount > 0 {
                Text("cache.selectionSummary".localized(cacheVM.selectedCount))
                    .foregroundStyle(Color.daSecondaryText)
                Spacer()
                Button("cache.select.none".localized) {
                    cacheVM.selection = []
                }
                Button("cache.clean".localized(Self.formatted(cacheVM.selectedSize))) {
                    isConfirmingClean = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.delete, modifiers: .command)
            } else if let result = cacheVM.lastResult {
                Image(systemName: result.failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(result.failedCount == 0 ? Color.daGreen : Color.daOrange)
                    .accessibilityHidden(true)
                Text(resultMessage(result))
                    .foregroundStyle(Color.daSecondaryText)
                Spacer()
                Button("common.close".localized, systemImage: "xmark") {
                    cacheVM.lastResult = nil
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(Color.daTertiaryText)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .padding(.horizontal, 24)
        .frame(height: 48)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func resultMessage(_ result: CacheCleanResult) -> String {
        let freed = "cache.result.freed".localized(Self.formatted(result.freedBytes))
        guard result.failedCount > 0 else { return freed }
        return freed + " · " + "cache.result.failed".localized(result.failedCount)
    }

    // MARK: - Formatting

    static func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.english.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Scan Strip

/// Slim progress line while projects are being measured. Results stay usable underneath.
private struct CacheScanStrip: View {
    let scanned: Int
    let total: Int

    private var fraction: Double {
        total > 0 ? min(Double(scanned) / Double(total), 1) : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.mini)

                Text("cache.scanning".localized)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.daSecondaryText)

                Text("cache.scanProgress".localized(scanned, total))
                    .monospacedDigit()
                    .foregroundStyle(Color.daTertiaryText)

                Spacer()

                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(Color.daTertiaryText)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 12)
            .frame(height: 28)

            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.daAccent)
                    .frame(width: proxy.size.width * fraction)
                    .animation(.linear(duration: 0.2), value: fraction)
            }
            .frame(height: 2)
            .background(Color.daBorder)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Filter Chip

private struct CacheFilterChip: View {
    let title: String
    let size: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.daAccentDark : Color.daSecondaryText)
                Text(size)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.daAccentDark.opacity(0.8) : Color.daTertiaryText)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(
                isSelected ? Color.daAccent.opacity(0.16) : Color.primary.opacity(isHovered ? 0.08 : 0.05),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Checkbox

/// A three-state checkbox: a project shows a dash while only some of its folders are picked.
private struct CacheCheckbox: View {
    let state: CacheSelectionState
    let label: String
    let action: () -> Void

    private var symbol: String {
        switch state {
        case .none: return "square"
        case .some: return "minus.square.fill"
        case .all: return "checkmark.square.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(state == .none ? Color.daMutedText : Color.daAccent)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(state == .none ? [] : .isSelected)
    }
}

// MARK: - Rows

private struct CacheProjectRow: View {
    let group: ProjectCacheGroup
    /// This project's share of the largest one in the list.
    let fraction: Double
    let isExpanded: Bool
    let selectionState: CacheSelectionState
    let isDisabled: Bool
    let onToggleSelection: () -> Void
    let onToggleExpansion: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            CacheCheckbox(state: selectionState, label: group.project.name, action: onToggleSelection)
                .disabled(isDisabled)

            Button(action: onToggleExpansion) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.daTertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)

                    ProjectFolderIcon(project: group.project, size: 24, isInteractive: false)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.project.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.daPrimaryText)
                            .lineLimit(1)

                        Text("\(group.project.projectType) · \(ProjectCacheContentView.relativeDate(group.project.lastModified))")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.daTertiaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    Text("cache.folderCount".localized(group.items.count))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.daMutedText)
                        .lineLimit(1)

                    sizeBar

                    Text(ProjectCacheContentView.formatted(group.totalSize))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.daPrimaryText)
                        .frame(width: 82, alignment: .trailing)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .onHover { isHovered = $0 }
    }

    private var sizeBar: some View {
        Capsule()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 72, height: 4)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.daAccent)
                    .frame(width: max(72 * fraction, 3), height: 4)
            }
            .accessibilityHidden(true)
    }
}

private struct CacheItemRow: View {
    let item: CacheItem
    let isSelected: Bool
    let isDisabled: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            CacheCheckbox(state: isSelected ? .all : .none, label: item.displayName, action: onToggle)
                .disabled(isDisabled)

            Text(item.displayName)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.daSecondaryText)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(item.kind.titleKey.localized)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.daTertiaryText)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .frame(height: 18)
                .background(Color.primary.opacity(0.06), in: Capsule())
                .fixedSize()

            Spacer(minLength: 12)

            Button("projects.revealInFinder".localized, systemImage: "arrow.up.forward.square") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Color.daTertiaryText)
            .opacity(isHovered ? 1 : 0)
            .help("projects.revealInFinder".localized)

            Text(ProjectCacheContentView.formatted(item.size))
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(Color.daSecondaryText)
                .frame(width: 82, alignment: .trailing)
        }
        .padding(.leading, 46)
        .padding(.trailing, 14)
        .frame(height: 34)
        .background(Color.primary.opacity(isHovered ? 0.05 : 0.02))
        .contentShape(Rectangle())
        .onTapGesture { if !isDisabled { onToggle() } }
        .onHover { isHovered = $0 }
    }
}
