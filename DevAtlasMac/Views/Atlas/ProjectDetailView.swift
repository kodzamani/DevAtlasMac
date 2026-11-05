import SwiftUI
import AppKit

struct ProjectDetailView: View {
    @Bindable var viewModel: AppViewModel
    let project: ProjectInfo
    
    @State private var stats: ProjectStats?
    @State private var codeAnalysis: CodeAnalysisResult?
    @State private var dependencies: ProjectDependencies?
    @State private var showEditorPicker = false
    @State private var showAnalyze = false
    @State private var showScriptPicker = false
    @State private var availableScripts: [ProjectRunner.PackageScript] = []
    @State private var versionCheckTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                projectHeader
                quickActionsSection
                statsRow
                techStackCard

                CollapsibleDependenciesSectionView(
                    project: project,
                    dependencies: dependencies
                )
            }
            .frame(maxWidth: 1100)
            .padding(.init(top: 20, leading: 24, bottom: 32, trailing: 24))
            .frame(maxWidth: .infinity)
        }
        // Separate tasks, so each section appears as soon as its own data is ready.
        .task {
            stats = await ProjectStatistics.calculate(for: project)
        }
        .task {
            codeAnalysis = await CodeAnalyzer.analyze(for: project)
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
        .sheet(isPresented: $showAnalyze) {
            analyzeSheet
        }
    }
    
    // MARK: - Project Header
    private var projectHeader: some View {
        HStack(spacing: 16) {
            ProjectFolderIcon(project: project, size: 76)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text(project.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.daPrimaryText)
                        .lineLimit(1)

                    if project.isActive {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.daGreen)
                                .frame(width: 6, height: 6)
                            Text("projects.active".localized)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.daTertiaryText)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Text(project.projectType)

                    if let branch = project.gitBranch {
                        metaItem(.branch, branch)
                    }

                    metaItem(.clock, timeAgoString(from: project.lastModified))
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.daTertiaryText)

                Button {
                    viewModel.revealInFinder(project)
                } label: {
                    Text(project.path)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.daMutedText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
                .help("projects.revealInFinder".localized)
            }

            Spacer(minLength: 0)
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
    private var quickActionsSection: some View {
        FlowLayout(spacing: 6) {
            if project.isAppleProject {
                CompactQuickActionCard(
                    glyph: .hammer,
                    title: "projects.openInXcode".localized
                ) {
                    viewModel.openInXcode(project)
                }
            }
            
            CompactQuickActionCard(
                glyph: .braces,
                title: "projects.openInCodeEditor".localized
            ) {
                showEditorPicker = true
            }
            .popover(isPresented: $showEditorPicker, arrowEdge: .bottom) {
                editorPickerPopover
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
                title: "projects.openTerminal".localized
            ) {
                viewModel.openTerminal(project)
            }
            
            CompactQuickActionCard(
                glyph: .folder,
                title: "projects.revealInFinder".localized
            ) {
                viewModel.revealInFinder(project)
            }
            
            CompactQuickActionCard(
                glyph: .bars,
                title: "projects.analyzeProject".localized
            ) {
                showAnalyze = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Overview
    private var statsRow: some View {
        HStack(spacing: 0) {
            StatMiniCard(label: "dashboard.size".localized, systemImage: "internaldrive", value: stats?.totalSize)
            statsDivider
            StatMiniCard(label: "dashboard.files".localized, systemImage: "doc.on.doc", value: codeAnalysis.map { formatNumber($0.totalFiles) })
            statsDivider
            StatMiniCard(label: "dashboard.lines".localized, systemImage: "text.alignleft", value: codeAnalysis.map { formatNumber($0.totalLines) })
        }
        .fixedSize(horizontal: false, vertical: true)
        .daCardSurface()
    }

    private var statsDivider: some View {
        Rectangle()
            .fill(Color.daCardEdge)
            .frame(width: 1)
            .padding(.vertical, 12)
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

    // MARK: - Format Number
    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    // MARK: - Analyze Sheet
    private var analyzeSheet: some View {
        VStack(spacing: 0) {
            // Sheet header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.daEmerald)
                    Text("analyze.projectsAnalyze".localized)
                        .font(.daSectionTitle)
                        .foregroundStyle(Color.daPrimaryText)
                }
                Spacer()
                Text(project.name)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                Button {
                    showAnalyze = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.daMutedText)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider()
                .foregroundStyle(Color.daBorder)
            
            // Content
            if let analysis = codeAnalysis {
                if analysis.totalFiles > 0 {
                    ScrollView {
                        ProjectAnalyzeView(
                            analysis: analysis,
                            projectPath: project.path,
                            runner: viewModel.runner
                        )
                            .padding(20)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.daMutedText)
                        Text("stats.noSourceFiles".localized)
                            .font(.daBody)
                            .foregroundStyle(Color.daMutedText)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    ProjectAnalyzeSkeleton()
                        .padding(20)
                }
                .scrollDisabled(true)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .frame(idealWidth: 900, idealHeight: 700)
        .background { AuroraBackground() }
        .task {
            if codeAnalysis == nil {
                codeAnalysis = await CodeAnalyzer.analyze(for: project)
            }
        }
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
