import SwiftUI

/// The Docker workspace's own vector icons (`docker-*` template assets on a 24pt grid).
struct DockerIcon: View {
    enum Kind: String {
        case whale, container, stack, image, compose
        case play, stop, restart, refresh, trash, logs, terminal
        case cpu, memory, port, volume, database, key, envfile, network, link
        case sliders, hammer, pencil, plus, folder, check, xmark, save, deploy, revert
        case power, filter, copy, external, eye, lock, search, more, warning, clock, arrow
        case cache, queue, bucket, mail, window
    }

    let kind: Kind
    let size: CGFloat

    init(_ kind: Kind, size: CGFloat = 16) {
        self.kind = kind
        self.size = size
    }

    var body: some View {
        Image("docker-" + kind.rawValue)
            .renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// An icon on a tinted rounded square; `filled` gives the header's gradient treatment.
struct DockerIconTile: View {
    let kind: DockerIcon.Kind
    var tint: Color = .daDocker
    var size: CGFloat = 32
    var filled = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        DockerIcon(kind, size: size * 0.5)
            .foregroundStyle(filled ? Color.white : tint)
            .frame(width: size, height: size)
            .background {
                if filled {
                    shape.fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(tint.opacity(0.12))
                }
            }
            .overlay(shape.strokeBorder(filled ? Color.white.opacity(0.18) : tint.opacity(0.14)))
            .shadow(color: filled ? tint.opacity(0.35) : .clear, radius: 8, y: 3)
    }
}

/// Round icon-only button used on cards. A nil tint keeps it neutral.
struct DockerIconButton: View {
    let kind: DockerIcon.Kind
    let help: String
    var tint: Color? = nil
    var size: CGFloat = 26
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            DockerIcon(kind, size: size * 0.48)
                .foregroundStyle(tint ?? Color.daSecondaryText)
                .frame(width: size, height: size)
                .background((tint ?? Color.primary).opacity(isHovered && isEnabled ? 0.16 : 0.07), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Text button with a leading icon, used in bars and empty states.
struct DockerActionButton: View {
    enum Style { case plain, prominent, destructive }

    let kind: DockerIcon.Kind
    let title: String
    var style: Style = .plain
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) { DockerActionLabel(kind: kind, title: title, style: style, isHovered: isHovered) }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
    }
}

struct DockerActionLabel: View {
    let kind: DockerIcon.Kind
    let title: String
    var style: DockerActionButton.Style = .plain
    var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        HStack(spacing: 6) {
            DockerIcon(kind, size: 13)
            Text(title).lineLimit(1)
        }
        .font(.system(size: 12, weight: style == .prominent ? .semibold : .medium))
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .frame(height: 28)
        .background {
            switch style {
            case .prominent:
                shape.fill(LinearGradient(colors: [Color.daDocker, Color.daDocker.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .brightness(isHovered ? 0.06 : 0)
            case .destructive:
                shape.fill(Color.red.opacity(isHovered ? 0.16 : 0.1))
            case .plain:
                shape.fill(Color.primary.opacity(isHovered ? 0.1 : 0.06))
            }
        }
        .overlay(shape.strokeBorder(style == .prominent ? Color.white.opacity(0.15) : Color.primary.opacity(0.07)))
        .shadow(color: style == .prominent ? Color.daDocker.opacity(0.3) : .clear, radius: 5, y: 2)
        .contentShape(shape)
    }

    private var foreground: Color {
        switch style {
        case .prominent: .white
        case .destructive: .red
        case .plain: Color.daPrimaryText
        }
    }
}

/// Small capsule with an optional icon.
struct DockerChip: View {
    var kind: DockerIcon.Kind? = nil
    let text: String
    var tint: Color = .secondary
    var monospaced = false

    var body: some View {
        HStack(spacing: 4) {
            if let kind { DockerIcon(kind, size: 10.5) }
            Text(text)
                .font(.system(size: 10.5, weight: .medium, design: monospaced ? .monospaced : .default))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(tint.opacity(0.1), in: Capsule())
    }
}

/// A state dot with a soft glow while the thing it describes is live.
struct DockerStatusDot: View {
    let color: Color
    var isLive = false
    var size: CGFloat = 7

    var body: some View {
        Circle().fill(color)
            .frame(width: size, height: size)
            .shadow(color: isLive ? color.opacity(0.7) : .clear, radius: 3)
    }
}

/// Section title with an icon, a count and trailing controls.
struct DockerSectionHeader<Trailing: View>: View {
    let kind: DockerIcon.Kind
    let title: String
    var count: Int? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            DockerIcon(kind, size: 15).foregroundStyle(Color.daDocker)
            Text(title).font(.system(size: 14, weight: .semibold))
            if let count {
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).frame(height: 18)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

extension DockerSectionHeader where Trailing == EmptyView {
    init(kind: DockerIcon.Kind, title: String, count: Int? = nil) {
        self.init(kind: kind, title: title, count: count) { EmptyView() }
    }
}

/// Inline notice for errors, warnings and results.
struct DockerBanner<Trailing: View>: View {
    let kind: DockerIcon.Kind
    let tint: Color
    let text: String
    var monospaced = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            DockerIcon(kind, size: 14).foregroundStyle(tint).padding(.top, 1)
            ScrollView {
                Text(text)
                    .font(.system(size: 11.5, design: monospaced ? .monospaced : .default))
                    .foregroundStyle(Color.daPrimaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .daScrollBounceBasedOnSize()
            .frame(maxHeight: 72)
            .fixedSize(horizontal: false, vertical: true)
            trailing()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.2)))
    }
}

extension DockerBanner where Trailing == EmptyView {
    init(kind: DockerIcon.Kind, tint: Color, text: String, monospaced: Bool = false) {
        self.init(kind: kind, tint: tint, text: text, monospaced: monospaced) { EmptyView() }
    }
}

/// Dashed placeholder used when a section has nothing to show.
struct DockerEmptyCard: View {
    let kind: DockerIcon.Kind
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            DockerIcon(kind, size: 16).foregroundStyle(.tertiary)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }
}

/// Grid card chrome shared by container and stack cards.
struct DockerCardChrome: ViewModifier {
    var tint: Color
    @State private var isHovered = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        content
            .padding(11)
            .background(.background.opacity(0.7), in: shape)
            .overlay(shape.strokeBorder(isHovered ? tint.opacity(0.45) : Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 8 : 3, y: 2)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

extension View {
    func dockerCard(tint: Color = .daDocker) -> some View { modifier(DockerCardChrome(tint: tint)) }

    /// Compact text field look for the Compose form.
    func dockerField(monospaced: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return textFieldStyle(.plain)
            .font(.system(size: 12, design: monospaced ? .monospaced : .default))
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color.primary.opacity(0.045), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.09)))
    }
}

extension DockerContainer {
    var stateColor: Color {
        switch state {
        case "running": .green
        case "paused": .orange
        case "restarting": .blue
        case "dead": .red
        default: .secondary
        }
    }
}

extension DockerDaemonState {
    var color: Color {
        switch self {
        case .running: .green
        case .stopped: .orange
        case .notInstalled: .red
        }
    }
}

extension DockerServiceTemplate {
    var icon: DockerIcon.Kind {
        switch self {
        case .postgres, .mysql, .mariadb, .mongodb: .database
        case .redis: .cache
        case .rabbitmq: .queue
        case .minio: .bucket
        case .mailpit: .mail
        case .pgadmin, .adminer: .window
        case .custom: .container
        }
    }
}

extension DockerIcon.Kind {
    /// Best-guess icon for an image reference, so service and container lists are scannable.
    static func forImage(_ image: String, isBuild: Bool = false) -> DockerIcon.Kind {
        if isBuild { return .hammer }
        let name = image.lowercased()
        let match: [(String, DockerIcon.Kind)] = [
            ("postgres", .database), ("mysql", .database), ("mariadb", .database), ("mongo", .database),
            ("redis", .cache), ("valkey", .cache), ("memcached", .cache), ("rabbitmq", .queue), ("kafka", .queue),
            ("nats", .queue), ("minio", .bucket), ("mailpit", .mail), ("mailhog", .mail),
            ("pgadmin", .window), ("adminer", .window), ("nginx", .network), ("traefik", .network), ("caddy", .network),
        ]
        return match.first { name.contains($0.0) }?.1 ?? .container
    }
}
