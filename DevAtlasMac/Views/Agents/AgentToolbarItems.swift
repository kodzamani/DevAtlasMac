import SwiftUI

/// Session tabs shown in the window toolbar while the Agents tab has running sessions.
struct AgentSessionTabs: View {
    let manager: AgentSessionsViewModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                ForEach(manager.sessions) { session in
                    AgentSessionTab(session: session,
                                    isSelected: session.id == manager.selectedSession?.id,
                                    showsSelection: manager.sessions.count > 1) {
                        manager.selectedSessionID = session.id
                    } onClose: {
                        manager.close(session)
                    }
                }
            }
            .padding(3)
        }
        .scrollIndicators(.never)
        // A toolbar item sizes to its ideal width; cap it so many tabs scroll instead of crowding the toolbar.
        .frame(maxWidth: 560)
    }
}

/// "New Session" toolbar button: switches to the agent start screen instead of opening a popover.
struct AgentNewSessionButton: View {
    let manager: AgentSessionsViewModel

    var body: some View {
        Button("agents.newSession".localized, systemImage: "plus") {
            manager.showComposer()
        }
        .help("agents.newSession".localized)
    }
}

struct AgentSessionTab: View {
    let session: AgentSession
    let isSelected: Bool
    /// A lone tab needs no highlight; the toolbar capsule already frames it.
    var showsSelection = true
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(session.isRunning ? Color.daGreen : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(session.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.daPrimaryText : Color.daSecondaryText)
            Text(session.projectName)
                .font(.system(size: 11))
                .foregroundStyle(Color.daSecondaryText)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.daSecondaryText)
                    .frame(width: 16, height: 16)
                    .background(Color.primary.opacity(isHovered ? 0.08 : 0), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("agents.close".localized)
        }
        .lineLimit(1)
        .padding(.leading, 11).padding(.trailing, 4)
        .frame(height: 24)
        .background(Color.primary.opacity(highlight), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
        .help(session.terminalTitle ?? session.directory)
    }

    private var highlight: Double {
        guard showsSelection else { return 0 }
        return isSelected ? 0.1 : (isHovered ? 0.05 : 0)
    }
}
