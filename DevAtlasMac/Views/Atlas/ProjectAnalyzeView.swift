import SwiftUI

import AppKit
import MarkdownUI

struct ProjectAnalyzeView: View {
    let analysis: CodeAnalysisResult
    let projectPath: String
    let runner: ProjectRunner
    
    @State private var currentPage = 0
    @State private var isAnalyzing = false
    @State private var showSuccessToast = false
    @State private var showMarkdownPreview = false
    @State private var generatedHTML = ""
    @State private var generatedMarkdownList = ""
    @State private var unusedCodeResults: [UnusedCodeResult] = []
    @State private var showNoUnusedCodeAlert = false
    @State private var showPeripheryInstallAlert = false
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
    
    // MARK: - Supported Languages for Unused Code Analysis
    
    private let supportedLanguagesForUnusedCode: Set<String> = ["Swift", "C#", "JavaScript", "Dart"]
    
    private var isUnusedCodeAnalysisSupported: Bool {
        // Check if any of the detected languages support unused code analysis
        let detectedLanguages = analysis.languageBreakdown.map { $0.language }
        return detectedLanguages.contains { supportedLanguagesForUnusedCode.contains($0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader
            summaryChips
            languageBreakdown
            fileTable
            if totalPages > 1 {
                paginationControls
            }
        }
        .padding(18)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.daBorder, lineWidth: 1)
        )
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
    
    // MARK: - Header
    
    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Text("analyze.projectsAnalyze".localized)
                .font(.daSectionTitle)
                .foregroundStyle(Color.daPrimaryText)
            Spacer()
            
            // Show unused code button only for supported languages
            if isUnusedCodeAnalysisSupported {
                Button(action: runUnusedCodeAnalyzer) {
                    HStack(spacing: 6) {
                        if isAnalyzing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11))
                        }
                        Text(isAnalyzing ? "analyze.analyzing".localized : (showSuccessToast ? "analyze.savedToNotes".localized : "analyze.findUnusedCode".localized))
                            .font(.daSmallLabelSemiBold)
                    }
                    .foregroundStyle(showSuccessToast ? Color.green : Color.daPrimaryText)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.daLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .disabled(isAnalyzing)
            }
            
            Text("\(analysis.totalFiles) \("analyze.filesAnalyzed".localized)")
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
        }
    }
    
    // MARK: - Summary Chips
    
    private var summaryChips: some View {
        HStack(spacing: 10) {
            SummaryChip(
                icon: "doc.text",
                label: "analyze.totalFiles".localized,
                value: formatNumber(analysis.totalFiles)
            )
            SummaryChip(
                icon: "text.alignleft",
                label: "analyze.totalLines".localized,
                value: formatNumber(analysis.totalLines)
            )
            SummaryChip(
                icon: "chart.bar",
                label: "analyze.avgLinesPerFile".localized,
                value: analysis.totalFiles > 0
                ? formatNumber(analysis.totalLines / analysis.totalFiles)
                : "–"
            )
            SummaryChip(
                icon: "star",
                label: "analyze.largestFile".localized,
                value: analysis.files.first.map { formatNumber($0.lineCount) + " lines" } ?? "–"
            )
        }
    }
    
    // MARK: - Language Breakdown
    
    private var languageBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stacked bar
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(analysis.languageBreakdown.prefix(8)) { lang in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: lang.color))
                            .frame(width: max(4, geometry.size.width * lang.percentage / 100))
                    }
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            
            // Language chips
            FlowLayout(spacing: 6) {
                ForEach(analysis.languageBreakdown.prefix(8)) { lang in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: lang.color))
                            .frame(width: 7, height: 7)
                        Text(lang.language)
                            .font(.daFont(size: 10, weight: .medium))
                            .foregroundStyle(Color.daSecondaryText)
                        Text(String(format: "%.1f%%", lang.percentage))
                            .font(.daFont(size: 10, weight: .regular))
                            .foregroundStyle(Color.daMutedText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.daLightGray)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.daVeryLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - File Table
    
    private var fileTable: some View {
        VStack(spacing: 0) {
            // Table header
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 36, alignment: .center)
                Text("analyze.file".localized)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("analyze.extension".localized)
                    .frame(width: 80, alignment: .center)
                Text("analyze.lines".localized)
                    .frame(width: 100, alignment: .trailing)
            }
            .font(.daSmallLabelSemiBold)
            .foregroundStyle(Color.daMutedText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.daLightGray)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Table rows
            ForEach(Array(currentPageFiles.enumerated()), id: \.element.id) { index, file in
                let globalIndex = currentPage * pageSize + index + 1
                FileTableRow(
                    index: globalIndex,
                    file: file,
                    maxLineCount: maxLineCount,
                    projectPath: projectPath,
                    runner: runner
                )
                
                if index < currentPageFiles.count - 1 {
                    Divider()
                        .foregroundStyle(Color.daBorder.opacity(0.5))
                        .padding(.horizontal, 10)
                }
            }
        }
    }
    
    // MARK: - Pagination
    
    private var paginationControls: some View {
        HStack {
            Text(String(format: "analyze.pageOf".localized, currentPage + 1, totalPages))
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
            
            Spacer()
            
            HStack(spacing: 4) {
                Button {
                    if currentPage > 0 { currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(currentPage > 0 ? Color.daBlue : Color.daMutedText)
                        .frame(width: 26, height: 26)
                        .background(Color.daLightGray)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(currentPage == 0)
                
                // Page number buttons
                ForEach(pageRange, id: \.self) { page in
                    Button {
                        currentPage = page
                    } label: {
                        Text("\(page + 1)")
                            .font(.daSmallLabelSemiBold)
                            .foregroundStyle(page == currentPage ? .white : Color.daSecondaryText)
                            .frame(width: 26, height: 26)
                            .background(page == currentPage ? Color.daBlue : Color.daLightGray)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    if currentPage < totalPages - 1 { currentPage += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(currentPage < totalPages - 1 ? Color.daBlue : Color.daMutedText)
                        .frame(width: 26, height: 26)
                        .background(Color.daLightGray)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(currentPage >= totalPages - 1)
            }
        }
        .padding(.top, 4)
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
    
    // MARK: - Helpers
    
    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    
    private func runUnusedCodeAnalyzer() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        showSuccessToast = false
        
        Task {
            do {
                let analyzer = UnusedCodeAnalyzer()
                let results = try await analyzer.analyze(projectPath: projectPath)
                
                await MainActor.run {
                    self.isAnalyzing = false
                    
                    if results.isEmpty {
                        self.showNoUnusedCodeAlert = true
                    } else {
                        let htmlContent = analyzer.generateMarkdownTable(from: results)
                        let listContent = analyzer.generateMarkdownList(from: results)
                        self.generatedHTML = htmlContent
                        self.generatedMarkdownList = listContent
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


