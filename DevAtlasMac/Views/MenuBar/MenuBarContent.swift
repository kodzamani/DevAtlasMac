import SwiftUI
import AppKit

/// The menu behind the menu bar icon. Works whether or not the main window is open.
struct MenuBarContent: View {
    static let mainWindowID = "main"

    let viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Strings are read from the selected language, which SwiftUI can't observe by itself.
        let _ = viewModel.languageRevision
        // Looked up once: a submenu per project would otherwise repeat it for every project.
        let editors = viewModel.installedEditors()

        Button("menuBar.open".localized) { showMainWindow() }

        Divider()

        Menu("nav.projects".localized) {
            if viewModel.menuProjects.isEmpty {
                Text("projects.noProjectsFound".localized)
            } else {
                ForEach(viewModel.menuProjectsByLanguage, id: \.language) { group in
                    Menu(group.language) {
                        ForEach(group.projects) { project in
                            Menu(project.name) {
                                ProjectContextMenu(viewModel: viewModel, project: project, editors: editors) {
                                    viewModel.openProject(project)
                                    showMainWindow()
                                }
                            }
                        }
                    }
                }
            }
        }

        Divider()

        Button("menuBar.quit".localized) { NSApp.terminate(nil) }
    }

    private func showMainWindow() {
        // Back in the Dock first, or the window opens behind the frontmost app.
        NSApp.setActivationPolicy(.regular)
        openWindow(id: Self.mainWindowID)
        NSApp.activate()
    }
}
