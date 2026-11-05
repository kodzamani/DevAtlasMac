import SwiftUI

/// Finder-style folder rendered by a Metal shader. Its light follows the pointer and the
/// front panel lifts on hover.
struct FolderIconView: View {
    let tint: Color
    let size: CGFloat
    var isInteractive: Bool = true

    @Environment(\.displayScale) private var displayScale
    @State private var pointer: CGPoint = .zero
    @State private var isHovered = false

    private var iconSize: CGSize { CGSize(width: size, height: size * 0.88) }

    var body: some View {
        Rectangle()
            .modifier(
                FolderShading(
                    size: iconSize,
                    tint: tint,
                    pointer: pointer,
                    hover: isHovered ? 1 : 0,
                    open: isHovered ? 1 : 0,
                    pixelSize: 1 / max(displayScale, 1)
                )
            )
            .frame(width: iconSize.width, height: iconSize.height)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onContinuousHover(coordinateSpace: .local) { phase in
                guard isInteractive else { return }
                switch phase {
                case .active(let location):
                    pointer = location
                    isHovered = true
                case .ended:
                    isHovered = false
                }
            }
            .accessibilityHidden(true)
    }
}

private struct FolderShading: ViewModifier, Animatable {
    let size: CGSize
    let tint: Color
    let pointer: CGPoint
    var hover: Double
    var open: Double
    let pixelSize: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(hover, open) }
        set {
            hover = newValue.first
            open = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content.colorEffect(
            ShaderLibrary.daFolderIcon(
                .float2(size),
                .color(tint),
                .float2(pointer),
                .float(hover),
                .float(open),
                .float(pixelSize)
            )
        )
    }
}

/// A project's folder, tinted with its language color and stamped with its glyph.
struct ProjectFolderIcon: View {
    let project: ProjectInfo
    let size: CGFloat
    var isInteractive: Bool = true

    var body: some View {
        FolderIconView(tint: Color(hex: project.displayIconColor), size: size, isInteractive: isInteractive)
            .overlay(alignment: .center) {
                if size >= 40 {
                    glyph
                        .foregroundStyle(.white.opacity(0.92))
                        .offset(y: size * 0.115)
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private var glyph: some View {
        if let assetName = project.iconAssetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.26, height: size * 0.26)
        } else if let systemImage = project.iconSystemImage {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.24, weight: .semibold))
        } else {
            Text(project.displayIconText)
                .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
        }
    }
}
