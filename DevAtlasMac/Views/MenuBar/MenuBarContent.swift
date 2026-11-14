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
        Button("menuBar.quickSearch".localized) { QuickSearchController.shared.show() }
            .keyboardShortcut(.space, modifiers: .control)

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

        Menu("tab.ports".localized) {
            Button("ports.showAll".localized) {
                viewModel.selectedTab = .ports
                showMainWindow()
            }
            Button("ports.refresh".localized) { Task { await viewModel.portManager.refresh() } }
            if let error = viewModel.portManager.errorMessage { Text(error) }
            if viewModel.projectPortListeners.isEmpty { Text("ports.empty".localized) }
            ForEach(viewModel.projectPortListeners) { listener in
                Menu("\(listener.port) · \(viewModel.project(for: listener)?.name ?? listener.command)") {
                    Text("\(listener.command) · PID \(listener.pid)")
                    Text(listener.workingDirectory ?? "ports.unknownDirectory".localized)
                    if let url = listener.browserURL {
                        Link("ports.openBrowser".localized, destination: url)
                    }
                    if let project = viewModel.project(for: listener) {
                        Button(project.name) {
                            viewModel.openProject(project)
                            showMainWindow()
                        }
                    }
                    Button("ports.stop".localized, role: .destructive) {
                        Task { await viewModel.portManager.stop(listener) }
                    }
                    .disabled(listener.startedAt == nil || viewModel.portManager.stoppingPIDs.contains(listener.pid))
                }
            }
        }

        Divider()

        Menu("tab.docker".localized) {
            Button("docker.showAll".localized) {
                viewModel.selectedTab = .docker
                showMainWindow()
            }
            Button("docker.refresh".localized) {
                Task { await viewModel.dockerManager.refresh(projects: viewModel.projects) }
            }.disabled(viewModel.dockerManager.isRefreshing)
            if let error = viewModel.dockerManager.errorMessage ?? viewModel.dockerManager.scanMessage { Text(error) }
            ForEach(viewModel.dockerManager.containers) { container in
                Menu("\(container.isRunning ? "●" : "○") \(container.name)") {
                    Text(container.image)
                    Text(container.stateTitle)
                    Button((container.isRunning ? "docker.action.stop" : "docker.action.start").localized) {
                        Task {
                            await viewModel.dockerManager.perform(container.isRunning ? .stop : .start, on: container, projects: viewModel.projects)
                        }
                    }.disabled(viewModel.dockerManager.busyIDs.contains(container.id) || !["running", "exited", "created"].contains(container.state))
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
