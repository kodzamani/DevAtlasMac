import SwiftUI

/// Finder's preview pane: a large icon, metadata and quick actions for the selected project.
struct ProjectPreviewPane: View {
    let viewModel: AppViewModel
    let project: ProjectInfo?

    var body: some View {
        Group {
            if let project {
                content(for: project)
                    .id(project.id)
                    .transition(.opacity)
            } else {
                Text("finder.noSelection".localized)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daMutedText)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: project?.id)
    }

    private func content(for project: ProjectInfo) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    ProjectFolderIcon(project: project, size: 96)

                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.daPrimaryText)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)

                    Text(project.projectType)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.daTertiaryText)
                }
                .padding(.top, 14)

                actions(for: project)
                information(for: project)

                if !project.tags.isEmpty {
                    tags(for: project)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func actions(for project: ProjectInfo) -> some View {
        HStack(spacing: 14) {
            actionButton("finder.open".localized, icon: "arrow.up.forward.app") {
                viewModel.selectProject(project)
            }
            actionButton(
                project.isAppleProject ? "projects.openInXcode".localized : "projects.openInCodeEditor".localized,
                icon: project.isAppleProject ? "hammer" : "curlybraces"
            ) {
                if project.isAppleProject {
                    viewModel.openInXcode(project)
                } else {
                    viewModel.openInVSCode(project)
                }
            }
            actionButton("projects.openTerminal".localized, icon: "terminal") {
                viewModel.openTerminal(project)
            }
            actionButton("projects.revealInFinder".localized, icon: "folder") {
                viewModel.revealInFinder(project)
            }
        }
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.daSecondaryText)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.daLightGray))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.daBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }

    private func information(for project: ProjectInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("finder.information".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.daPrimaryText)

            Divider()

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 7) {
                row("finder.dateModified".localized, project.lastModified.formatted(date: .abbreviated, time: .shortened))
                if let branch = project.gitBranch {
                    row("finder.branch".localized, branch)
                }
                if let files = project.totalFiles {
                    row("projects.footer.files".localized, files.formatted())
                }
                if let lines = project.totalLines {
                    row("projects.footer.lines".localized, lines.formatted())
                }
                row("finder.path".localized, project.path)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(Color.daMutedText)
                .gridColumnAlignment(.trailing)
            Text(value)
                .foregroundStyle(Color.daSecondaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 11))
    }

    private func tags(for project: ProjectInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("finder.tags".localized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.daPrimaryText)

            Divider()

            FlowLayout(spacing: 5) {
                ForEach(project.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.daSecondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.daLightGray))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
