import SwiftUI
import AppKit

// MARK: - Page

/// A project's code analysis as a full page: it takes over the content area and steps back out.
struct ProjectAnalysisPage: View {
    let project: ProjectInfo
    /// Nil while the analysis is still running.
    let analysis: CodeAnalysisResult?
    let runner: ProjectRunner
    let onBack: () -> Void

    private let contentWidth: CGFloat = 1100

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
                .frame(maxWidth: contentWidth)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)

            Divider().overlay(Color.daCardEdge)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            AnalysisBackButton(action: onBack)

            VStack(alignment: .leading, spacing: 1) {
                Text("analyze.title".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daTertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            if let analysis, UnusedCodeButton.supports(analysis) {
                UnusedCodeButton(projectPath: project.path)
            }
        }
    }

    private var subtitle: String {
        guard let analysis else { return project.name }
        return "\(project.name) · \(analysis.totalFiles.formatted()) \("analyze.filesAnalyzed".localized)"
    }

    @ViewBuilder
    private var content: some View {
        if let analysis {
            if analysis.totalFiles > 0 {
                GeometryReader { geometry in
                    ScrollView {
                        ProjectAnalyzeView(
                            analysis: analysis,
                            projectPath: project.path,
                            runner: runner,
                            isWide: geometry.size.width >= 900
                        )
                        .frame(maxWidth: contentWidth)
                        .padding(.init(top: 20, leading: 24, bottom: 32, trailing: 24))
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28, weight: .light))
                    Text("stats.noSourceFiles".localized)
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.daTertiaryText)
            }
        } else {
            ScrollView {
                ProjectAnalyzeSkeleton()
                    .frame(maxWidth: contentWidth)
                    .padding(.init(top: 20, leading: 24, bottom: 32, trailing: 24))
                    .frame(maxWidth: .infinity)
            }
            .scrollDisabled(true)
        }
    }
}

private struct AnalysisBackButton: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.daSecondaryText)
                .frame(width: 30, height: 30)
                .background(
                    Color.primary.opacity(isHovered ? 0.09 : 0.05),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .onHover { isHovered = $0 }
        .help("finder.back".localized)
        .accessibilityLabel("finder.back".localized)
    }
}

// MARK: - Content

struct ProjectAnalyzeView: View {
    let analysis: CodeAnalysisResult
    let projectPath: String
    let runner: ProjectRunner
    let isWide: Bool

    @State private var currentPage = 0
    private let pageSize = 30

    private var totalPages: Int {
        max(1, Int(ceil(Double(analysis.files.count) / Double(pageSize))))
    }

    private var currentPageFiles: [FileLineInfo] {
        let start = currentPage * pageSize
        let end = min(start + pageSize, analysis.files.count)
        guard start < analysis.files.count else { return [] }
        return Array(analysis.files[start..<end])
    }

    private var maxLineCount: Int {
        analysis.files.first?.lineCount ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryStrip

            if isWide {
                HStack(alignment: .top, spacing: 18) {
                    fileTable
                    languagesCard
                        .frame(width: 290)
                }
            } else {
                languagesCard
                fileTable
            }
        }
    }

    // MARK: - Summary

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            StatMiniCard(label: "analyze.totalFiles".localized, value: analysis.totalFiles.formatted())
            StatStripDivider()
            StatMiniCard(label: "analyze.totalLines".localized, value: analysis.totalLines.formatted())
            StatStripDivider()
            StatMiniCard(
                label: "analyze.avgLinesPerFile".localized,
                value: analysis.totalFiles > 0 ? (analysis.totalLines / analysis.totalFiles).formatted() : "–"
            )
            StatStripDivider()
            StatMiniCard(
                label: "analyze.largestFile".localized,
                value: analysis.files.first?.lineCount.formatted() ?? "–",
                footnote: analysis.files.first.map { ($0.relativePath as NSString).lastPathComponent }
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .daCardSurface()
    }

    private var languagesCard: some View {
        ProjectLanguagesCard(analysis: analysis, showsAllLanguages: true)
    }

    // MARK: - File Table

    private var fileTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: FileTableColumn.index, alignment: .center)
                Text("analyze.file".localized)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("analyze.extension".localized)
                    .frame(width: FileTableColumn.fileExtension, alignment: .leading)
                Text("analyze.lines".localized)
                    .frame(width: FileTableColumn.lines, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.daTertiaryText)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Color.primary.opacity(0.025))

            ForEach(Array(currentPageFiles.enumerated()), id: \.element.id) { index, file in
                Divider().overlay(Color.daCardEdge)
                FileTableRow(
                    index: currentPage * pageSize + index + 1,
                    file: file,
                    maxLineCount: maxLineCount,
                    projectPath: projectPath,
                    runner: runner
                )
            }

            if totalPages > 1 {
                Divider().overlay(Color.daCardEdge)
                paginationControls
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .daCardSurface()
    }

    // MARK: - Pagination

    private var paginationControls: some View {
        HStack {
            Text(String(format: "analyze.pageOf".localized, currentPage + 1, totalPages))
                .font(.system(size: 11))
                .foregroundStyle(Color.daTertiaryText)

            Spacer()

            HStack(spacing: 4) {
                pageStepButton(systemImage: "chevron.left", isEnabled: currentPage > 0) {
                    currentPage -= 1
                }

                ForEach(pageRange, id: \.self) { page in
                    Button {
                        currentPage = page
                    } label: {
                        Text("\(page + 1)")
                            .font(.system(size: 11, weight: page == currentPage ? .semibold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(page == currentPage ? Color.white : Color.daSecondaryText)
                            .frame(width: 26, height: 26)
                            .background(
                                page == currentPage ? Color.daAccent : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                pageStepButton(systemImage: "chevron.right", isEnabled: currentPage < totalPages - 1) {
                    currentPage += 1
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func pageStepButton(systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.daSecondaryText : Color.daMutedText.opacity(0.6))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var pageRange: [Int] {
        let maxVisible = 5
        let half = maxVisible / 2
        var start = max(0, currentPage - half)
        var end = min(totalPages - 1, start + maxVisible - 1)
        start = max(0, end - maxVisible + 1)
        end = min(totalPages - 1, start + maxVisible - 1)
        return Array(start...end)
    }
}

// MARK: - Unused Code

/// Runs the unused code analyzer for a project and presents what it finds.
private struct UnusedCodeButton: View {
    let projectPath: String

    @State private var isAnalyzing = false
    @State private var isHovered = false
    @State private var showMarkdownPreview = false
    @State private var generatedHTML = ""
    @State private var unusedCodeResults: [UnusedCodeResult] = []
    @State private var showNoUnusedCodeAlert = false
    @State private var showPeripheryInstallAlert = false

    private static let supportedLanguages: Set<String> = ["Swift", "C#", "JavaScript", "Dart"]

    static func supports(_ analysis: CodeAnalysisResult) -> Bool {
        analysis.languageBreakdown.contains { supportedLanguages.contains($0.language) }
    }

    var body: some View {
        Button(action: run) {
            HStack(spacing: 6) {
                if isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? Color.daAccent : Color.daTertiaryText)
                        .frame(width: 14, height: 14)
                }
                Text(isAnalyzing ? "analyze.analyzing".localized : "analyze.findUnusedCode".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Color.primary.opacity(isHovered ? 0.09 : 0.05),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzing)
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showMarkdownPreview) {
            MarkdownPreviewSheet(
                htmlContent: generatedHTML,
                results: unusedCodeResults,
                projectPath: projectPath,
                onCancel: {
                    showMarkdownPreview = false
                }
            )
        }
        .alert("analyze.noUnusedCode".localized, isPresented: $showNoUnusedCodeAlert) {
            Button("common.done".localized, role: .cancel) { }
        }
        .alert("analyze.peripheryRequired".localized, isPresented: $showPeripheryInstallAlert) {
            Button("analyze.installPeriphery".localized) {
                openPeripheryInstallationGuide()
            }
            Button("common.cancel".localized, role: .cancel) { }
        } message: {
            Text("analyze.peripheryRequiredMessage".localized)
        }
    }

    private func run() {
        guard !isAnalyzing else { return }
        isAnalyzing = true

        Task {
            do {
                let analyzer = UnusedCodeAnalyzer()
                let results = try await analyzer.analyze(projectPath: projectPath)

                await MainActor.run {
                    self.isAnalyzing = false

                    if results.isEmpty {
                        self.showNoUnusedCodeAlert = true
                    } else {
                        self.generatedHTML = analyzer.generateMarkdownTable(from: results)
                        self.unusedCodeResults = results
                        self.showMarkdownPreview = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    if case AnalyzerError.peripheryNotFound = error {
                        self.showPeripheryInstallAlert = true
                    }
                }
                print("Failed to run analyzer: \(error)")
            }
        }
    }

    private func openPeripheryInstallationGuide() {
        guard let url = URL(string: "https://github.com/peripheryapp/periphery#installation") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

// MARK: - Skeleton

/// The analysis page's layout while its numbers are being worked out.
struct ProjectAnalyzeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SkeletonBlock(cornerRadius: 12)
                .frame(height: 72)

            SkeletonCard {
                VStack(spacing: 14) {
                    ForEach(0..<10, id: \.self) { _ in
                        SkeletonBlock(cornerRadius: 4)
                            .frame(height: 14)
                    }
                }
            }
        }
    }
}
