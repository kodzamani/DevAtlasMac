import SwiftUI

/// The main Atlas screen: the selected view mode, Finder's preview pane, path bar and status bar.
struct ProjectBrowserView: View {
    @Bindable var viewModel: AppViewModel
    var onShowOnboarding: (() -> Void)? = nil

    @AppStorage("browserIconSize") private var iconSize: Double = 64

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.filteredProjects.isEmpty {
                if viewModel.scanProgress.isScanning {
                    Color.clear
                } else {
                    emptyState
                }
            } else {
                HStack(spacing: 0) {
                    browser
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if viewModel.isPreviewPaneVisible && viewModel.viewMode != .columns {
                        Divider()
                        ProjectPreviewPane(viewModel: viewModel, project: viewModel.highlightedProject)
                            .frame(width: 270)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isPreviewPaneVisible)

                bottomBar
            }
        }
    }

    @ViewBuilder
    private var browser: some View {
        switch viewModel.viewMode {
        case .icons:
            ProjectIconGridView(viewModel: viewModel, iconSize: iconSize)
        case .list:
            ProjectTableView(viewModel: viewModel)
        case .columns:
            ProjectColumnsView(viewModel: viewModel)
        }
    }

    // MARK: - Bottom Bar

    /// One transparent row: location on the left, totals in the center, view controls on the right.
    private var bottomBar: some View {
        HStack(spacing: 12) {
            BrowserPathBar(viewModel: viewModel)
                .frame(maxWidth: .infinity)

            statusText
                .fixedSize()

            HStack(spacing: 10) {
                Spacer(minLength: 0)

                #if DEBUG
                if let onShowOnboarding {
                    Button(action: onShowOnboarding) {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.daTertiaryText)
                    .help("sidebar.showTour".localized)
                }
                #endif

                if viewModel.viewMode == .icons {
                    Slider(value: $iconSize, in: 48...112)
                        .controlSize(.mini)
                        .frame(width: 84)
                        .accessibilityLabel("finder.iconSize".localized)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12)
        .frame(height: 28)
        .overlay(alignment: .top) { Divider() }
    }

    private var statusText: some View {
        HStack(spacing: 6) {
            if viewModel.isCalculatingStats {
                ProgressView().controlSize(.mini)
                Text("projects.calculatingStats".localized)
            } else {
                Text("\(viewModel.filteredProjects.count) " + "common.items".localized)
                Text("·")
                Text("\(viewModel.filteredTotalFiles.formatted()) " + "projects.footer.files".localized)
                Text("·")
                Text("\(viewModel.filteredTotalLines.formatted()) " + "projects.footer.lines".localized)
            }
        }
        .foregroundStyle(Color.daTertiaryText)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            FolderIconView(tint: Color.daAccent, size: 96)
                .padding(.bottom, 4)

            Text("projects.noProjectsFound".localized)
                .font(.daSectionTitle)
                .foregroundStyle(Color.daSecondaryText)

            Text("projects.tryScanning".localized)
                .font(.daBody)
                .foregroundStyle(Color.daTertiaryText)

            Button("projects.scanProjects".localized, systemImage: "wand.and.rays") {
                Task { await viewModel.startScan() }
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Finder's path bar. Shows the selected project's location, or the current sidebar location.
struct BrowserPathBar: View {
    let viewModel: AppViewModel

    private struct Segment: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        var path: String?
    }

    private var segments: [Segment] {
        guard let project = viewModel.highlightedProject else {
            return [
                Segment(id: "app", title: "nav.devAtlas".localized, systemImage: "square.grid.2x2.fill"),
                Segment(id: "location", title: viewModel.locationTitle, systemImage: "folder.fill")
            ]
        }

        var current = ""
        return project.path.split(separator: "/").map { component in
            current += "/\(component)"
            return Segment(id: current, title: String(component), systemImage: "folder.fill", path: current)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                pathSegments
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .leading)
            }
            .defaultScrollAnchor(.trailing)
        }
    }

    private var pathSegments: some View {
        HStack(spacing: 3) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                if index > 0 {
                    Image(systemName: "chevron.compact.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.daMutedText)
                }
                Button {
                    if let path = segment.path {
                        viewModel.runner.revealInFinder(at: path)
                    }
                } label: {
                    Label {
                        Text(segment.title).lineLimit(1)
                    } icon: {
                        Image(systemName: segment.systemImage)
                            .foregroundStyle(Color.daAccent)
                            .font(.system(size: 10))
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daSecondaryText)
                }
                .buttonStyle(.plain)
                .disabled(segment.path == nil)
            }
        }
    }
}
