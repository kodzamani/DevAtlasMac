import SwiftUI
import AppKit

/// Actions shared by the context menus and the toolbar's action menu.
struct ProjectContextMenu: View {
    let viewModel: AppViewModel
    let project: ProjectInfo

    var body: some View {
        Button("finder.open".localized) { viewModel.selectProject(project) }

        Divider()

        if project.isAppleProject {
            Button("projects.openInXcode".localized) { viewModel.openInXcode(project) }
        }

        Menu("common.openWith".localized) {
            ForEach(viewModel.installedEditors()) { editor in
                Button(editor.name) { viewModel.openInEditor(editor, project: project) }
            }
        }

        Button("projects.openTerminal".localized) { viewModel.openTerminal(project) }
        Button("projects.revealInFinder".localized) { viewModel.revealInFinder(project) }

        Divider()

        Button("finder.copyPath".localized) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(project.path, forType: .string)
        }
    }
}
