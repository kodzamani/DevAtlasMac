import SwiftUI

/// Shared layout constants for the Chat tab.
enum ChatMetrics {
    static let columnWidth: CGFloat = 720
    static let composerCorner: CGFloat = 22
    static let cardCorner: CGFloat = 14
    static let bubbleCorner: CGFloat = 18
}

/// A small keyboard key, as in the quick search panel.
struct ChatKeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 18)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
    }
}

struct ChatKeyHint: View {
    let keys: [String]
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { ChatKeyCap(text: $0) }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

struct ChatTypePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

/// A square tile with a white line icon on a tinted fill, like QuickSearch action rows.
struct ChatIconTile: View {
    let glyph: ChatGlyph
    let tint: Color
    var size: CGFloat = 26

    var body: some View {
        ChatIcon(glyph, size: size * 0.56, weight: 1.7)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .fill(tint.gradient)
            )
    }
}

/// Capsule chip used for suggestion and follow-up actions.
struct ChatChipButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        ChatChipBody(configuration: configuration, tint: tint, isDestructive: isDestructive)
    }

    private struct ChatChipBody: View {
        let configuration: Configuration
        let tint: Color?
        let isDestructive: Bool
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(isDestructive ? Color.red : Color.daPrimaryText)
                .padding(.horizontal, 12)
                .frame(minHeight: 30)
                .background(Capsule().fill(Color.primary.opacity(isHovered ? 0.1 : 0.06)))
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(isEnabled ? 1 : 0.5)
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

/// Liquid Glass on macOS 26, a blurred panel with a hairline elsewhere.
struct ChatGlassBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.daCardEdge, lineWidth: 0.75))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
        }
    }
}

extension View {
    func chatGlass(cornerRadius: CGFloat) -> some View {
        modifier(ChatGlassBackground(cornerRadius: cornerRadius))
    }
}

extension Int64 {
    var chatByteString: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

/// A flat, borderless surface: a faint tint in dark mode, a card with a hairline in light mode.
struct ChatSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if colorScheme == .dark {
            content.background(Color.white.opacity(0.05), in: shape)
        } else {
            content
                .background(Color.daCard, in: shape)
                .overlay(shape.strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5).allowsHitTesting(false))
        }
    }
}

extension View {
    func chatSurface(cornerRadius: CGFloat) -> some View {
        modifier(ChatSurface(cornerRadius: cornerRadius))
    }
}
