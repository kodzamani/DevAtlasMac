import SwiftUI

/// Coding agents (Claude Code, OpenCode, Codex…) running in embedded terminals, one tab per session.
struct AgentsContentView: View {
    let viewModel: AppViewModel
    private var manager: AgentSessionsViewModel { viewModel.agentManager }

    var body: some View {
        // Keep this screen's ideal size from enlarging the split view and shifting its sidebar.
        GeometryReader { geometry in
            Group {
                if manager.sessions.isEmpty {
                    AgentsEmptyStateView(viewModel: viewModel)
                        .transition(.opacity)
                } else {
                    sessionArea
                        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .animation(.easeOut(duration: 0.2), value: manager.sessions.isEmpty)
        .task { await manager.ensureDetected() }
    }

    // MARK: Sessions

    @ViewBuilder
    private var sessionArea: some View {
        if let session = manager.selectedSession ?? manager.sessions.first {
            VStack(spacing: 0) {
                if case .exited(let code) = session.state {
                    exitedBanner(session, code: code)
                }
                AgentTerminalView(session: session, isDarkMode: viewModel.isDarkMode)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.daCardEdge))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func exitedBanner(_ session: AgentSession, code: Int32?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "stop.circle").foregroundStyle(.secondary)
            Text(code.map { "agents.exited".localized(String($0)) } ?? "agents.ended".localized)
                .font(.daBody)
            Spacer()
            Button("agents.restart".localized) { manager.restart(session) }
            Button("agents.close".localized) { manager.close(session) }
        }
        .controlSize(.small)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.primary.opacity(0.05))
    }
}
