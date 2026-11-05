import SwiftUI
import AppKit
import MarkdownUI

struct ProjectGitCard: View {
    let projectPath: String

    @State private var state: ProjectGitState?
    @State private var refreshID = 0
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                OverviewCardHeading(title: "detail.git.title".localized, icon: "point.3.connected.trianglepath.dotted")
                Spacer()
                Button {
                    refreshID += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.daTertiaryText)
                .disabled(isLoading)
                .help("detail.git.refresh".localized)
                .accessibilityLabel("detail.git.refresh".localized)
            }

            switch state {
            case .repository(let summary):
                repositoryContent(summary)
            case .notRepository:
                OverviewEmptyState(icon: "point.3.connected.trianglepath.dotted", message: "detail.git.noRepository".localized)
            case .unavailable:
                OverviewEmptyState(icon: "exclamationmark.circle", message: "detail.git.unavailable".localized)
            case nil:
                OverviewLoadingState()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .daCardSurface()
        .task(id: refreshID) {
            isLoading = true
            let result = await ProjectOverviewService.gitSummary(at: projectPath)
            guard !Task.isCancelled else { return }
            state = result
            isLoading = false
        }
    }

    private func repositoryContent(_ summary: ProjectGitSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(summary.branch ?? "detail.git.detached".localized, systemImage: "arrow.triangle.branch")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.daPrimaryText)
                .lineLimit(2)
                .textSelection(.enabled)

            Label(
                summary.changedFiles == 0 ? "detail.git.clean".localized : "detail.git.changedFiles".localized(summary.changedFiles),
                systemImage: summary.changedFiles == 0 ? "checkmark.circle.fill" : "circle.lefthalf.filled"
            )
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(summary.changedFiles == 0 ? Color.daGreen : Color.daOrange)

            Divider().overlay(Color.daCardEdge)

            if let commit = summary.commit {
                VStack(alignment: .leading, spacing: 7) {
                    Text("detail.git.lastCommit".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.daTertiaryText)
                    Text(commit.subject)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.daSecondaryText)
                        .lineLimit(3)
                        .textSelection(.enabled)
                    HStack(spacing: 8) {
                        Text(commit.hash).fontDesign(.monospaced)
                        Text(commit.date, style: .relative)
                            .help(commit.date.formatted(date: .complete, time: .shortened))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Color.daTertiaryText)
                }
            } else {
                Text("detail.git.noCommits".localized)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daTertiaryText)
            }

            if let remote = summary.remoteURL {
                Link(destination: remote) {
                    Label("detail.git.openRemote".localized, systemImage: "arrow.up.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.daAccent)
                .help(remote.absoluteString)
            }
        }
    }
}

struct ProjectLanguagesCard: View {
    let analysis: CodeAnalysisResult?

    private var languages: [LanguageBreakdown] {
        guard let breakdown = analysis?.languageBreakdown else { return [] }
        guard breakdown.count > 6 else { return breakdown }
        return Array(breakdown.prefix(5)) + [LanguageBreakdown(
            language: "detail.languages.other".localized,
            percentage: breakdown.dropFirst(5).reduce(0) { $0 + $1.percentage },
            color: "8E8E93"
        )]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OverviewCardHeading(title: "detail.languages.title".localized, icon: "chart.bar.xaxis")

            if analysis == nil {
                OverviewLoadingState()
            } else if languages.isEmpty {
                OverviewEmptyState(icon: "curlybraces", message: "stats.noSourceFiles".localized)
            } else {
                distributionBar

                VStack(spacing: 10) {
                    ForEach(languages, id: \.language) { language in
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: language.color)).frame(width: 7, height: 7)
                            Text(language.language)
                                .foregroundStyle(Color.daSecondaryText)
                            Spacer(minLength: 8)
                            Text(language.percentage / 100, format: .percent.precision(.fractionLength(1)))
                                .monospacedDigit()
                                .foregroundStyle(Color.daTertiaryText)
                        }
                        .font(.system(size: 11))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .daCardSurface()
    }

    private var distributionBar: some View {
        Canvas { context, size in
            let total = languages.reduce(0) { $0 + $1.percentage }
            guard total > 0 else { return }
            var x: CGFloat = 0
            for language in languages {
                let width = size.width * language.percentage / total
                let rect = CGRect(x: x, y: 0, width: width, height: size.height)
                context.fill(Path(rect), with: .color(Color(hex: language.color)))
                x += width
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

struct ProjectReadmeSection: View {
    let projectPath: String

    @State private var state: ProjectReadmeState?
    @State private var showFullReadme = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                OverviewCardHeading(title: "README", icon: "doc.text")
                Spacer()
                if case .document(let document) = state {
                    Button {
                        showFullReadme = true
                    } label: {
                        Label("detail.readme.readFull".localized, systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.daAccent)
                    .disabled(document.content.isEmpty)
                }
            }

            switch state {
            case .document(let document):
                if document.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    OverviewEmptyState(icon: "doc.text", message: "detail.readme.empty".localized)
                } else {
                    ReadmeDocumentContent(document: document, isPreview: true)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: 340, alignment: .topLeading)
                        .clipped()
                        .contentShape(Rectangle())
                    Divider().overlay(Color.daCardEdge)
                    HStack {
                        Text(document.url.lastPathComponent)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.daTertiaryText)
                        Spacer()
                        openFileButton(document.url)
                    }
                }
            case .missing:
                OverviewEmptyState(icon: "doc.text.magnifyingglass", message: "detail.readme.missing".localized)
            case .unreadable:
                OverviewEmptyState(icon: "exclamationmark.circle", message: "detail.readme.unreadable".localized)
            case .tooLarge(let url):
                OverviewEmptyState(icon: "doc.text", message: "detail.readme.tooLarge".localized)
                openFileButton(url)
            case nil:
                OverviewLoadingState()
                    .frame(minHeight: 180)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: projectPath) {
            state = nil
            let result = await ProjectOverviewService.readme(at: projectPath)
            guard !Task.isCancelled else { return }
            state = result
        }
        .sheet(isPresented: $showFullReadme) {
            if case .document(let document) = state {
                ReadmeDocumentSheet(document: document)
            }
        }
    }

    private func openFileButton(_ url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Label("detail.readme.openFile".localized, systemImage: "arrow.up.forward.app")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.daAccent)
    }
}

private struct ReadmeDocumentContent: View {
    let document: ProjectReadme
    var isPreview = false

    var body: some View {
        Group {
            if document.isMarkdown {
                Markdown(isPreview ? document.preview : document.content, baseURL: document.url.deletingLastPathComponent())
                    .markdownTheme(.basic)
                    .markdownTextStyle { FontSize(12) }
            } else {
                Text(isPreview ? document.preview : document.content)
                    .font(.system(size: 12))
            }
        }
        .foregroundStyle(Color.daSecondaryText)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReadmeDocumentSheet: View {
    let document: ProjectReadme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OverviewCardHeading(title: document.url.lastPathComponent, icon: "doc.text")
                Spacer()
                Button("detail.readme.close".localized) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            ScrollView {
                ReadmeDocumentContent(document: document)
                    .padding(24)
            }
        }
        .frame(minWidth: 640, idealWidth: 820, minHeight: 480, idealHeight: 680)
        .background(Color.daOffWhite)
    }
}

private struct OverviewCardHeading: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.daPrimaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct OverviewLoadingState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock().frame(height: 12)
            SkeletonBlock().frame(maxWidth: 160).frame(height: 10)
            SkeletonBlock().frame(maxWidth: 110).frame(height: 10)
        }
        .padding(.vertical, 4)
        .accessibilityLabel("detail.loading".localized)
    }
}

private struct OverviewEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 23, weight: .light))
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.daTertiaryText)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
