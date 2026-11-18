import SwiftUI

/// The welcome screen of a new conversation: a mark, a greeting and a few things to start with.
struct ChatEmptyStateView: View {
    @ObservedObject var chatVM: ChatViewModel

    @State private var hasAppeared = false

    private enum Card: Identifiable {
        case project(ProjectInfo)
        case command(ChatSlashCommand)

        var id: String {
            switch self {
            case .project(let project): return "project:\(project.id)"
            case .command(let command): return "command:\(command.rawValue)"
            }
        }
    }

    private var cards: [Card] {
        let projects = chatVM.recentProjects.prefix(4).map(Card.project)
        let commands: [ChatSlashCommand] = projects.isEmpty ? [.rescan, .help] : [.recent, .stats]
        return projects + commands.map(Card.command)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "chat.empty.morning".localized
        case 12..<18: return "chat.empty.afternoon".localized
        default: return "chat.empty.evening".localized
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    mark
                        .padding(.bottom, 20)
                        .modifier(ChatEntryStagger(isVisible: hasAppeared, index: 0))

                    Text(greeting)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.daPrimaryText)
                        .multilineTextAlignment(.center)
                        .modifier(ChatEntryStagger(isVisible: hasAppeared, index: 1))

                    Text("chat.empty.subtitle".localized)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.daTertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .modifier(ChatEntryStagger(isVisible: hasAppeared, index: 2))

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            cardView(card)
                                .modifier(ChatEntryStagger(isVisible: hasAppeared, index: index + 3))
                        }
                    }
                    .padding(.top, 28)
                }
                .frame(maxWidth: ChatMetrics.columnWidth)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .daScrollBounceBasedOnSize()
        }
        .onAppear { hasAppeared = true }
    }

    private var mark: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.daAccent.opacity(0.22), Color.daAccent.opacity(0.06)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 40
                    )
                )
            Circle()
                .strokeBorder(Color.daAccent.opacity(0.28), lineWidth: 1)
            LineGlyphView(glyph: .chat, isSelected: true)
                .scaleEffect(1.75)
        }
        .frame(width: 68, height: 68)
        .shadow(color: Color.daAccent.opacity(0.18), radius: 16, y: 4)
    }

    @ViewBuilder
    private func cardView(_ card: Card) -> some View {
        switch card {
        case .project(let project):
            ChatSuggestionCard(
                title: project.name,
                subtitle: project.projectType,
                help: project.path
            ) {
                ProjectFolderIcon(project: project, size: 30, isInteractive: false)
            } action: {
                chatVM.selectProject(project)
            }
        case .command(let command):
            ChatSuggestionCard(
                title: command.title,
                subtitle: command.token,
                subtitleIsMonospaced: true,
                help: command.token
            ) {
                ChatIconTile(glyph: command.glyph, tint: Self.tint(for: command), size: 30)
            } action: {
                chatVM.run(command)
            }
        }
    }

    private static func tint(for command: ChatSlashCommand) -> Color {
        switch command {
        case .recent: return Color(hex: "5E5CE6")
        case .ports: return Color(hex: "30B158")
        case .stats: return Color(hex: "0A84FF")
        case .rescan: return Color(hex: "30B158")
        case .new: return Color(hex: "8E8E93")
        case .help: return Color(hex: "FF9F0A")
        }
    }
}

/// Fades and lifts each element in, one after another.
private struct ChatEntryStagger: ViewModifier {
    let isVisible: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(.snappy(duration: 0.4).delay(Double(index) * 0.045), value: isVisible)
    }
}

/// A tappable starter card: icon, title and one line of detail. Lifts slightly on hover.
private struct ChatSuggestionCard<Icon: View>: View {
    let title: String
    let subtitle: String
    var subtitleIsMonospaced = false
    let help: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.daPrimaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(subtitleIsMonospaced
                              ? .system(size: 11.5, design: .monospaced)
                              : .system(size: 11.5))
                        .foregroundStyle(Color.daTertiaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                ChatIcon(.arrowUpRight, size: 11.5)
                    .foregroundStyle(Color.daTertiaryText)
                    .opacity(isHovered ? 1 : 0)
                    .offset(x: isHovered ? 0 : -4, y: isHovered ? 0 : 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .chatSurface(cornerRadius: ChatMetrics.cardCorner)
            .overlay(
                RoundedRectangle(cornerRadius: ChatMetrics.cardCorner, style: .continuous)
                    .strokeBorder(Color.daAccent.opacity(isHovered ? 0.45 : 0), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: ChatMetrics.cardCorner, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.03 : 0))
            )
            .shadow(color: .black.opacity(isHovered ? 0.10 : 0), radius: 10, y: 4)
            .offset(y: isHovered ? -2 : 0)
            .contentShape(RoundedRectangle(cornerRadius: ChatMetrics.cardCorner, style: .continuous))
        }
        .buttonStyle(ChatPressableStyle())
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.22), value: isHovered)
        .help(help)
    }
}

private struct ChatPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
