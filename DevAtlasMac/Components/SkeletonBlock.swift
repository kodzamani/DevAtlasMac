import SwiftUI

/// A loading placeholder for one piece of content: a neutral shape with a faint accent sweep.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.6

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(Color.primary.opacity(0.07))
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, Color.daAccent.opacity(0.18), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: proxy.size.width * phase)
                }
                .clipShape(shape)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityHidden(true)
    }
}

/// A placeholder for a whole card. It stays see-through, so loading never flashes a bright panel.
struct SkeletonCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.primary.opacity(0.025), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }
}

/// A placeholder for a card holding a title and one chart or table.
struct SkeletonChartCard: View {
    let height: CGFloat

    var body: some View {
        SkeletonCard {
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock()
                    .frame(width: 150, height: 16)
                SkeletonBlock(cornerRadius: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: height - 40)
        }
    }
}
