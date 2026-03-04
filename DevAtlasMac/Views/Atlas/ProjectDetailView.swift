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
            VStack(alignment: .leading, spacing: 0) {
                backButton
                projectHeader
                techStackAndDependenciesCard
            }
            .padding(.init(top: 20, leading: 20, bottom: 32, trailing: 20))
        }
        .background(Color.daOffWhite)
        .task {
            async let s = ProjectStatistics.calculate(for: project)
            async let a = CodeAnalyzer.analyze(for: project)
            async let d = DependenciesService.getDependencies(for: project)
            stats = await s
            codeAnalysis = await a
            let loadedDeps = await d
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
    
    // MARK: - Back Button
    private var backButton: some View {
        Button {
            viewModel.goBack()
        } label: {
            HStack(spacing: 6) {
                Text("←")
                    .font(.daSectionHeader)
                    .foregroundStyle(Color.daTertiaryText)
                Text("projects.backToProjects".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daTertiaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.daLightGray)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.daBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 18)
    }
    
    // MARK: - Project Header
    private var projectHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left side: Icon
            Group {
                if let assetName = project.iconAssetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.white)
                } else if let systemImage = project.iconSystemImage {
                    Image(systemName: systemImage)
                        .font(.daIconText)
                        .foregroundStyle(.white)
                } else {
                    Text(project.displayIconText)
                        .font(.daIconText)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 52, height: 52)
            .background(Color(hex: project.displayIconColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Left side: Project info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text(project.name)
                        .font(.daProjectTitle)
                        .foregroundStyle(Color.daPrimaryText)
                    
                    if project.isActive {
                        Text("projects.active".localized)
                            .font(.daFileExtensionMedium)
                            .foregroundStyle(Color.daDarkGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.daLightGreen)
                            .clipShape(Capsule())
                    }
                    
                    // Git branch badge (now on the left)
                    if let branch = project.gitBranch {
                        gitBranchBadge(branch)
                    }
                    
                    // Last modified badge (now on the left)
                    lastModifiedBadge
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.daTertiaryText.opacity(0.5))
                    Text(project.path)
                        .font(.daBody)
                        .foregroundStyle(Color.daTertiaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            // Right side: Quick Actions Grid
            quickActionsSection
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Last Modified Badge
    private var lastModifiedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text(timeAgoString(from: project.lastModified))
                .font(.daSmallLabel)
        }
        .foregroundStyle(Color.daMutedText)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.daLightGray)
        .clipShape(Capsule())
    }
    
    // MARK: - Time Ago Helper
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .weekOfYear], from: date, to: now)
        
        if let weeks = components.weekOfYear, weeks >= 1 {
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        } else if let days = components.day, days >= 1 {
            return days == 1 ? "1 day" : "\(days) days"
        } else if let hours = components.hour, hours >= 1 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else if let minutes = components.minute, minutes >= 1 {
            return minutes == 1 ? "1 min" : "\(minutes) mins"
        } else {
            return "Just now"
        }
    }
    
    private func gitBranchBadge(_ branch: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9))
            Text(branch)
                .font(.daSmallLabel)
                .foregroundStyle(Color.daSecondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.daLightGray)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.daBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
    
    // MARK: - Quick Actions (2-column grid on the right)
    private var quickActionsSection: some View {
        HStack(spacing: 8) {
            if project.isAppleProject {
                CompactQuickActionCard(
                    icon: "hammer.fill",
                    iconColor: .daBlue,
                    title: "projects.openInXcode".localized
                ) {
                    viewModel.openInXcode(project)
                }
            }
            
            CompactQuickActionCard(
                icon: "curlybraces",
                iconColor: .daBlue,
                title: "projects.openInCodeEditor".localized
            ) {
                showEditorPicker = true
            }
            .popover(isPresented: $showEditorPicker, arrowEdge: .bottom) {
                editorPickerPopover
            }
            
            if viewModel.runner.isRunnableProject(at: project.path) {
                CompactQuickActionCard(
                    icon: "play.fill",
                    iconColor: .daEmerald,
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
                icon: "terminal",
                iconColor: .daPrimaryText,
                title: "projects.openTerminal".localized
            ) {
                viewModel.openTerminal(project)
            }
            
            CompactQuickActionCard(
                icon: "folder",
                iconColor: .daTertiaryText,
                title: "projects.revealInFinder".localized
            ) {
                viewModel.revealInFinder(project)
            }
            
            CompactQuickActionCard(
                icon: "chart.bar.doc.horizontal",
                iconColor: .daEmerald,
                title: "projects.analyzeProject".localized
            ) {
                showAnalyze = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Tech Stack & Dependencies Combined Card
    private var techStackAndDependenciesCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            VStack(alignment: .leading, spacing: 14) {
                Text("projects.techStack".localized)
                    .font(.daSubSectionSemiBold)
                    .foregroundStyle(Color.daPrimaryText)
                
                FlowLayout(spacing: 8) {
                    ForEach(project.tags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.daBlue)
                                .frame(width: 6, height: 6)
                            Text(tag)
                                .font(.daTechTag)
                                .foregroundStyle(Color.daDarkBlue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.daLightBlue)
                        .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    Text("projects.type".localized)
                        .font(.daFileExtension)
                        .foregroundStyle(Color.daTertiaryText)
                    Text(project.projectType)
                        .font(.daFileExtensionMedium)
                        .foregroundStyle(Color.daSecondaryText)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.daLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Stats row
                HStack(spacing: 10) {
                    StatMiniCard(label: "dashboard.size".localized, value: stats?.totalSize ?? "–")
                    StatMiniCard(label: "dashboard.files".localized, value: codeAnalysis.map { "\($0.totalFiles)" } ?? "–")
                    StatMiniCard(label: "dashboard.lines".localized, value: codeAnalysis.map { formatNumber($0.totalLines) } ?? "–")
                }
            }
            .frame(maxWidth: 500, alignment: .topLeading)
            
            CollapsibleDependenciesSectionView(
                project: project,
                dependencies: dependencies
            )
            
           
            
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.daBorder, lineWidth: 1)
        )
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
            .background(Color.daWhite)
            
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
                Spacer()
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("stats.analyzingProject".localized)
                        .font(.daBody)
                        .foregroundStyle(Color.daMutedText)
                }
                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .frame(idealWidth: 900, idealHeight: 700)
        .background(Color.daOffWhite)
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
        .background(Color.daWhite)
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
        .background(Color.daWhite)
    }
}
