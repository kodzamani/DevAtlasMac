import SwiftUI
import AppKit

struct ProjectDetailView: View {
    @Bindable var viewModel: AppViewModel
    let project: ProjectInfo
    
    @State private var stats: ProjectStats?
    @State private var codeAnalysis: CodeAnalysisResult?
    @State private var dependencies: ProjectDependencies?
    @State private var showEditorPicker = false
    @State private var showScriptPicker = false
    @State private var availableScripts: [ProjectRunner.PackageScript] = []
    @State private var versionCheckTask: Task<Void, Never>?
    
    var body: some View {
        DrillInContainer(isPresented: viewModel.isShowingProjectAnalysis) {
            overviewPage
        } detail: {
            ProjectAnalysisPage(
                project: project,
                analysis: codeAnalysis,
                runner: viewModel.runner
            ) {
                viewModel.isShowingProjectAnalysis = false
            }
        }
        // Separate tasks, so each section appears as soon as its own data is ready.
        .task {
            let result = await ProjectStatistics.calculate(for: project)
            guard !Task.isCancelled else { return }
            stats = result
        }
        .task {
            let result = await CodeAnalyzer.analyze(for: project)
            guard !Task.isCancelled else { return }
            codeAnalysis = result
        }
        .task {
            let loadedDeps = await DependenciesService.getDependencies(for: project)
            guard !Task.isCancelled else { return }
            dependencies = loadedDeps
            
            // Fetch latest versions in the background and update UI progressively
            versionCheckTask = Task {
                let enriched = await VersionCheckerService.enrichWithLatestVersions(loadedDeps)
                guard !Task.isCancelled else { return }
                await MainActor.run { dependencies = enriched }
            }
            
            // Load scripts for run project
            if !Task.isCancelled, viewModel.runner.isRunnableProject(at: project.path) {
                availableScripts = viewModel.getProjectScripts(project)
            }
        }
        .onDisappear {
            versionCheckTask?.cancel()
            versionCheckTask = nil
        }
    }
    
    // MARK: - Overview Page
    private var overviewPage: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    projectHeader(isWide: geometry.size.width >= 820)
                    statsRow
                    overviewCards(isWide: geometry.size.width >= 900)
                }
                .frame(maxWidth: 1100)
                .padding(.init(top: 22, leading: 24, bottom: 32, trailing: 24))
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Project Header
    private func projectHeader(isWide: Bool) -> some View {
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 14))

        return layout {
            projectIdentity
                .frame(maxWidth: .infinity, alignment: .leading)
            actionBar
                .fixedSize()
        }
        .padding(.bottom, 4)
    }

    private var projectIdentity: some View {
        HStack(spacing: 14) {
            ProjectFolderIcon(project: project, size: 60)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(project.name)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.daPrimaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    if project.isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.daGreen)
                                .frame(width: 6, height: 6)
                            Text("projects.active".localized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.daDarkGreen)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.daGreen.opacity(0.12), in: Capsule())
                        .fixedSize()
                    }
                }

                HStack(spacing: 10) {
                    Text(project.projectType)

                    if let branch = project.gitBranch {
                        metaItem(.branch, branch)
                    }

                    metaItem(.clock, timeAgoString(from: project.lastModified))
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.daTertiaryText)
                .lineLimit(1)

                Button {
                    viewModel.revealInFinder(project)
                } label: {
                    Text((project.path as NSString).abbreviatingWithTildeInPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.daMutedText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
                .help("projects.revealInFinder".localized)
            }
        }
    }

    private func metaItem(_ glyph: LineGlyph, _ text: String) -> some View {
        HStack(spacing: 3) {
            LineGlyphView(glyph: glyph)
                .scaleEffect(0.72)
                .frame(width: 14, height: 14)
            Text(text)
                .lineLimit(1)
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.english.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        HStack(spacing: 6) {
            if project.isAppleProject {
                CompactQuickActionCard(
                    glyph: .hammer,
                    title: "projects.openInXcode".localized,
                    style: .primary
                ) {
                    viewModel.openInXcode(project)
                }

                codeEditorButton(style: .iconOnly)
            } else {
                codeEditorButton(style: .primary)
            }

            if viewModel.runner.isRunnableProject(at: project.path) {
                CompactQuickActionCard(
                    glyph: .play,
                    title: "projects.runProject".localized
                ) {
                    // Use preloaded scripts
                    if availableScripts.isEmpty {
                        availableScripts = viewModel.getProjectScripts(project)
                    }

                    // If no scripts found, try running with default command
                    if availableScripts.isEmpty {
                        viewModel.runProject(project)
                        return
                    }

                    // Show picker if more than 1 script, otherwise run directly
                    if availableScripts.count > 1 {
                        showScriptPicker = true
                    } else if let firstScript = availableScripts.first {
                        viewModel.runProject(project, script: firstScript.name)
                    }
                }
                .popover(isPresented: $showScriptPicker, arrowEdge: .bottom) {
                    scriptPickerPopover
                }
            }

            CompactQuickActionCard(
                glyph: .terminal,
                title: "projects.openTerminal".localized,
                style: .iconOnly
            ) {
                viewModel.openTerminal(project)
            }

            CompactQuickActionCard(
                glyph: .folder,
                title: "projects.revealInFinder".localized,
                style: .iconOnly
            ) {
                viewModel.revealInFinder(project)
            }
        }
    }

    private func codeEditorButton(style: CompactQuickActionCard.Style) -> some View {
        CompactQuickActionCard(
            glyph: .braces,
            title: "projects.openInCodeEditor".localized,
            style: style
        ) {
            showEditorPicker = true
        }
        .popover(isPresented: $showEditorPicker, arrowEdge: .bottom) {
            editorPickerPopover
        }
    }

    // MARK: - Overview
    private func overviewCards(isWide: Bool) -> some View {
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 18))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))

        return layout {
            VStack(alignment: .leading, spacing: 18) {
                ProjectReadmeSection(projectPath: project.path)
                    .daCardSurface()

                CollapsibleDependenciesSectionView(dependencies: dependencies)
                    .daCardSurface()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
                ProjectGitCard(projectPath: project.path)
                ProjectLanguagesCard(analysis: codeAnalysis)
                if !project.tags.isEmpty {
                    techStackCard
                }
            }
            .frame(width: isWide ? 290 : nil)
            .frame(maxWidth: isWide ? nil : .infinity)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            StatMiniCard(label: "dashboard.size".localized, value: stats?.totalSize)
            StatStripDivider()
            StatMiniCard(label: "dashboard.files".localized, value: codeAnalysis?.totalFiles.formatted())
            StatStripDivider()
            StatMiniCard(label: "dashboard.lines".localized, value: codeAnalysis?.totalLines.formatted())
            StatStripDivider()
            StatMiniCard(label: "projects.dependencies".localized, value: dependencies?.totalCount.formatted())
            StatStripDivider()
            AnalyzeEntryButton {
                viewModel.isShowingProjectAnalysis = true
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .daCardSurface()
    }

    // MARK: - Tech Stack
    private var techStackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("projects.techStack".localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.daPrimaryText)

            FlowLayout(spacing: 6) {
                ForEach(project.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.daSecondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .daCardSurface()
    }

    // MARK: - Editor Picker Popover
    
    private var editorPickerPopover: some View {
        let editors = viewModel.installedEditors()
        return VStack(alignment: .leading, spacing: 0) {
            Text("projects.chooseEditor".localized)
                .font(.daBodySemiBold)
                .foregroundStyle(Color.daPrimaryText)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Divider()
            
            if editors.isEmpty {
                Text("projects.noEditorsFound".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                    .padding(16)
            } else {
                VStack(spacing: 0) {
                    ForEach(editors) { editor in
                        EditorPickerRow(
                            editor: editor,
                            icon: viewModel.runner.editorIcon(for: editor)
                        ) {
                            viewModel.openInEditor(editor, project: project)
                            showEditorPicker = false
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 220)
    }
    
    // MARK: - Script Picker Popover
    
    private var scriptPickerPopover: some View {
        let hasNodeModules = viewModel.hasNodeModules(project)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("projects.chooseScript".localized)
                    .font(.daBodySemiBold)
                    .foregroundStyle(Color.daPrimaryText)
                Spacer()
                if !hasNodeModules {
                    Text("install")
                        .font(.daSmallLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.daOrange)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(availableScripts) { script in
                        Button {
                            viewModel.runProject(project, script: script.name)
                            showScriptPicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(script.name)
                                        .font(.daBodyMedium)
                                        .foregroundStyle(Color.daPrimaryText)
                                    Text(script.command)
                                        .font(.daSmallLabel)
                                        .foregroundStyle(Color.daMutedText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.daEmerald)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 300)
        .frame(minHeight: 180, maxHeight: 400)
    }
}

/// The way into the code analysis page, at the end of the stats strip whose numbers it explains.
private struct AnalyzeEntryButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                LineGlyphView(glyph: .bars, isSelected: isHovered)

                Text("projects.analyzeProject".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.daTertiaryText)
                    .offset(x: isHovered ? 2 : 0)
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
            .background(Color.primary.opacity(isHovered ? 0.04 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}
