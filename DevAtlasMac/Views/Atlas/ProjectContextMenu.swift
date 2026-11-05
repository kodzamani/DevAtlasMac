import SwiftUI
import AppKit

/// Actions shared by the context menus and the toolbar's action menu.
struct ProjectContextMenu: View {
    let viewModel: AppViewModel
    let project: ProjectInfo
    /// Already looked up by the caller, when it shows this menu for many projects at once.
    var editors: [CodeEditor]?
    /// Replaces selecting the project in the browser, for menus shown outside the window.
    var onOpen: (() -> Void)?

    var body: some View {
        Button("finder.open".localized) {
            if let onOpen {
                onOpen()
            } else {
                viewModel.selectProject(project)
            }
        }

        Divider()

        if project.isAppleProject {
            Button("projects.openInXcode".localized) { viewModel.openInXcode(project) }
        }

        Menu("common.openWith".localized) {
            ForEach(editors ?? viewModel.installedEditors()) { editor in
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
