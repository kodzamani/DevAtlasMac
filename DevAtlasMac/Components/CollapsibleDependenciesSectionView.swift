import SwiftUI

// MARK: - Collapsible Dependencies Section View

/// The project's packages behind a disclosure header. Only the header toggles the section,
/// so the table below it stays free to select from.
struct CollapsibleDependenciesSectionView: View {
    let dependencies: ProjectDependencies?

    @State private var isExpanded = false
    /// The table is built the first time it opens, then kept so reopening costs nothing.
    @State private var hasMountedContent = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canExpand: Bool {
        dependencies?.hasDependencies == true
    }

    private var upgradeableCount: Int {
        guard let dependencies else { return 0 }
        let all = dependencies.directDependencies
            + dependencies.devDependencies
            + dependencies.projectGroups.flatMap(\.dependencies)
        return all.filter(\.isUpgradeable).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if canExpand {
                Button(action: toggle) { header }
                    .buttonStyle(.plain)
            } else {
                header
            }

            VerticalReveal(progress: isExpanded ? 1 : 0) {
                if hasMountedContent {
                    expandedContent
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: .daVerifyDeps)) { _ in toggle() } // TEMPVERIFY
    }

    private func toggle() {
        hasMountedContent = true
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.92)) {
            isExpanded.toggle()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            OverviewCardHeading(title: "projects.dependencies".localized, icon: "shippingbox")

            if canExpand, let dependencies {
                Text(dependencies.totalCount.formatted())
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.daTertiaryText)
            }

            Spacer(minLength: 8)

            headerAccessory
        }
        .padding(18)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.2), value: upgradeableCount)
    }

    @ViewBuilder
    private var headerAccessory: some View {
        if let dependencies {
            if dependencies.hasDependencies {
                if upgradeableCount > 0 {
                    Text("dependency.upgradeableCount".localized(upgradeableCount))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.daTertiaryText)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14)
            } else {
                Text("projects.noDependencies".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daTertiaryText)
            }
        } else {
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("projects.loadingDependencies".localized)
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        if let dependencies {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(dependencies.projectGroups) { group in
                    DependencyTable(
                        title: group.projectName,
                        showsFolderIcon: true,
                        dependencies: group.dependencies
                    )
                }

                if !dependencies.directDependencies.isEmpty {
                    DependencyTable(
                        title: "projects.dependencies".localized,
                        dependencies: dependencies.directDependencies
                    )
                }

                if !dependencies.devDependencies.isEmpty {
                    DependencyTable(
                        title: "projects.devDependencies".localized,
                        dependencies: dependencies.devDependencies
                    )
                }
            }
        }
    }
}

// MARK: - Vertical Reveal

/// Grows from nothing to its content's full height. The content is always laid out at full
/// size and only the frame around it animates, so rows never reflow while it opens or closes.
private struct VerticalReveal: Layout {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else {
            return CGSize(width: proposal.width ?? 0, height: 0)
        }
        let size = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? size.width, height: size.height * progress)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: nil)
        )
    }
}

// MARK: - Dependency Table

private enum DependencyColumn {
    static let version: CGFloat = 176
    static let source: CGFloat = 96
}

private struct DependencyTable: View {
    let title: String
    var showsFolderIcon = false
    let dependencies: [Dependency]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if showsFolderIcon {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.daTertiaryText)
                }

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(dependencies.count.formatted())
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Color.daTertiaryText)
            }

            VStack(spacing: 0) {
                columnHeader

                ForEach(dependencies) { dependency in
                    Divider().overlay(Color.daCardEdge)
                    DependencyRow(dependency: dependency)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.daCardEdge, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 12) {
            Text("dependency.package".localized)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("dependency.version".localized)
                .frame(width: DependencyColumn.version, alignment: .leading)
            Text("dependency.source".localized)
                .frame(width: DependencyColumn.source, alignment: .leading)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(Color.daTertiaryText)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Color.primary.opacity(0.025))
    }
}

private struct DependencyRow: View {
    let dependency: Dependency

    @State private var isHovered = false

    /// Regular and dev packages are told apart by their table, so only the rarer kinds get a tag.
    private var typeTag: String? {
        switch dependency.type {
        case .peer, .optional, .transitive:
            return dependency.type.rawValue
        case .regular, .dev:
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(dependency.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daPrimaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                if let typeTag {
                    Text(typeTag)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.daTertiaryText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            version
                .frame(width: DependencyColumn.version, alignment: .leading)

            source
                .frame(width: DependencyColumn.source, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Color.primary.opacity(isHovered ? 0.035 : 0))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var version: some View {
        Group {
            if dependency.isUpgradeable, let latest = dependency.latestVersion {
                HStack(spacing: 4) {
                    Text(dependency.displayVersion)
                        .foregroundStyle(Color.daTertiaryText)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.orange)
                    Text(latest)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.orange)
                }
                .help("\("dependency.upgradeable".localized): \(dependency.displayVersion) → \(latest)")
            } else {
                Text(dependency.displayVersion)
                    .foregroundStyle(Color.daSecondaryText)
                    .help(dependency.displayVersion)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .lineLimit(1)
        .truncationMode(.middle)
    }

    private var source: some View {
        HStack(spacing: 5) {
            sourceIcon
                .frame(width: 14, height: 14)
            Text(dependency.source.displayName)
                .font(.system(size: 11))
                .foregroundStyle(Color.daTertiaryText)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch dependency.source {
        case .npm:
            Image("npm").resizable()
        case .go:
            Image("go").resizable()
        case .nuget:
            Image("nuget").resizable()
        case .spm:
            symbol("swift")
        case .cocoapods:
            symbol("p.circle.fill")
        case .carthage:
            symbol("c.circle.fill")
        case .yarn, .pnpm, .pub, .cargo:
            symbol("shippingbox")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 11))
            .foregroundStyle(Color.daTertiaryText)
    }
}
