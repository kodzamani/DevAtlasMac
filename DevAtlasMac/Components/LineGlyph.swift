import SwiftUI

/// The app's own line icons, all drawn on an 18×18 grid with one stroke weight.
enum LineGlyph {
    case folder
    case globe
    case desktop
    case phone
    case cloud
    case bars
    case notebook
    case sparkle
    case sliders
    case scan
    case funnel
    case magnifier
    case clock
    case hammer
    case braces
    case terminal
    case play
    case branch

    fileprivate var path: Path {
        var p = Path()

        switch self {
        case .folder:
            p.move(to: CGPoint(x: 2.5, y: 5))
            p.addQuadCurve(to: CGPoint(x: 4, y: 3.5), control: CGPoint(x: 2.5, y: 3.5))
            p.addLine(to: CGPoint(x: 6.8, y: 3.5))
            p.addLine(to: CGPoint(x: 8.5, y: 5.5))
            p.addLine(to: CGPoint(x: 14, y: 5.5))
            p.addQuadCurve(to: CGPoint(x: 15.5, y: 7), control: CGPoint(x: 15.5, y: 5.5))
            p.addLine(to: CGPoint(x: 15.5, y: 13))
            p.addQuadCurve(to: CGPoint(x: 14, y: 14.5), control: CGPoint(x: 15.5, y: 14.5))
            p.addLine(to: CGPoint(x: 4, y: 14.5))
            p.addQuadCurve(to: CGPoint(x: 2.5, y: 13), control: CGPoint(x: 2.5, y: 14.5))
            p.closeSubpath()

        case .globe:
            p.addEllipse(in: CGRect(x: 2.5, y: 2.5, width: 13, height: 13))
            p.addEllipse(in: CGRect(x: 6.2, y: 2.5, width: 5.6, height: 13))
            p.move(to: CGPoint(x: 2.5, y: 9))
            p.addLine(to: CGPoint(x: 15.5, y: 9))

        case .desktop:
            p.addRoundedRect(in: CGRect(x: 2.5, y: 3, width: 13, height: 9.5), cornerSize: CGSize(width: 1.6, height: 1.6))
            p.move(to: CGPoint(x: 9, y: 12.5))
            p.addLine(to: CGPoint(x: 9, y: 15))
            p.move(to: CGPoint(x: 6.2, y: 15))
            p.addLine(to: CGPoint(x: 11.8, y: 15))

        case .phone:
            p.addRoundedRect(in: CGRect(x: 5, y: 2, width: 8, height: 14), cornerSize: CGSize(width: 2, height: 2))
            p.move(to: CGPoint(x: 8, y: 13.5))
            p.addLine(to: CGPoint(x: 10, y: 13.5))

        case .cloud:
            p.move(to: CGPoint(x: 5.2, y: 14))
            p.addCurve(to: CGPoint(x: 2, y: 11), control1: CGPoint(x: 3.3, y: 14), control2: CGPoint(x: 2, y: 12.7))
            p.addCurve(to: CGPoint(x: 4.7, y: 8), control1: CGPoint(x: 2, y: 9.4), control2: CGPoint(x: 3.1, y: 8.2))
            p.addCurve(to: CGPoint(x: 9.3, y: 4), control1: CGPoint(x: 5.1, y: 5.6), control2: CGPoint(x: 7, y: 4))
            p.addCurve(to: CGPoint(x: 13.7, y: 7.9), control1: CGPoint(x: 11.6, y: 4), control2: CGPoint(x: 13.4, y: 5.6))
            p.addCurve(to: CGPoint(x: 16, y: 10.9), control1: CGPoint(x: 15.2, y: 8.1), control2: CGPoint(x: 16, y: 9.4))
            p.addCurve(to: CGPoint(x: 13, y: 14), control1: CGPoint(x: 16, y: 12.6), control2: CGPoint(x: 14.8, y: 14))
            p.closeSubpath()

        case .bars:
            let corner = CGSize(width: 0.9, height: 0.9)
            p.addRoundedRect(in: CGRect(x: 2.5, y: 9.5, width: 3.4, height: 6), cornerSize: corner)
            p.addRoundedRect(in: CGRect(x: 7.3, y: 2.5, width: 3.4, height: 13), cornerSize: corner)
            p.addRoundedRect(in: CGRect(x: 12.1, y: 6, width: 3.4, height: 9.5), cornerSize: corner)

        case .notebook:
            p.addRoundedRect(in: CGRect(x: 3.5, y: 2.5, width: 11, height: 13), cornerSize: CGSize(width: 1.8, height: 1.8))
            p.move(to: CGPoint(x: 6.5, y: 2.5))
            p.addLine(to: CGPoint(x: 6.5, y: 15.5))
            p.move(to: CGPoint(x: 9, y: 6.5))
            p.addLine(to: CGPoint(x: 12, y: 6.5))
            p.move(to: CGPoint(x: 9, y: 9.5))
            p.addLine(to: CGPoint(x: 12, y: 9.5))

        case .sparkle:
            p.move(to: CGPoint(x: 8, y: 4.5))
            p.addQuadCurve(to: CGPoint(x: 13.5, y: 10), control: CGPoint(x: 8.6, y: 9.4))
            p.addQuadCurve(to: CGPoint(x: 8, y: 15.5), control: CGPoint(x: 8.6, y: 10.6))
            p.addQuadCurve(to: CGPoint(x: 2.5, y: 10), control: CGPoint(x: 7.4, y: 10.6))
            p.addQuadCurve(to: CGPoint(x: 8, y: 4.5), control: CGPoint(x: 7.4, y: 9.4))
            p.closeSubpath()
            p.move(to: CGPoint(x: 14, y: 2))
            p.addLine(to: CGPoint(x: 14, y: 6))
            p.move(to: CGPoint(x: 12, y: 4))
            p.addLine(to: CGPoint(x: 16, y: 4))

        case .sliders:
            p.move(to: CGPoint(x: 2.5, y: 5.5))
            p.addLine(to: CGPoint(x: 9.6, y: 5.5))
            p.addEllipse(in: CGRect(x: 9.6, y: 3.6, width: 3.8, height: 3.8))
            p.move(to: CGPoint(x: 13.4, y: 5.5))
            p.addLine(to: CGPoint(x: 15.5, y: 5.5))
            p.move(to: CGPoint(x: 2.5, y: 12.5))
            p.addLine(to: CGPoint(x: 4.6, y: 12.5))
            p.addEllipse(in: CGRect(x: 4.6, y: 10.6, width: 3.8, height: 3.8))
            p.move(to: CGPoint(x: 8.4, y: 12.5))
            p.addLine(to: CGPoint(x: 15.5, y: 12.5))

        case .scan:
            for (corner, dx, dy) in [(CGPoint(x: 2.5, y: 2.5), 1.0, 1.0), (CGPoint(x: 15.5, y: 2.5), -1.0, 1.0),
                                     (CGPoint(x: 2.5, y: 15.5), 1.0, -1.0), (CGPoint(x: 15.5, y: 15.5), -1.0, -1.0)] {
                p.move(to: CGPoint(x: corner.x, y: corner.y + 3.5 * dy))
                p.addLine(to: corner)
                p.addLine(to: CGPoint(x: corner.x + 3.5 * dx, y: corner.y))
            }
            p.move(to: CGPoint(x: 5, y: 9))
            p.addLine(to: CGPoint(x: 13, y: 9))

        case .funnel:
            p.move(to: CGPoint(x: 2.5, y: 5))
            p.addLine(to: CGPoint(x: 15.5, y: 5))
            p.move(to: CGPoint(x: 5, y: 9))
            p.addLine(to: CGPoint(x: 13, y: 9))
            p.move(to: CGPoint(x: 7.5, y: 13))
            p.addLine(to: CGPoint(x: 10.5, y: 13))

        case .magnifier:
            p.addEllipse(in: CGRect(x: 2.5, y: 2.5, width: 10, height: 10))
            p.move(to: CGPoint(x: 11, y: 11))
            p.addLine(to: CGPoint(x: 15.5, y: 15.5))

        case .clock:
            p.addEllipse(in: CGRect(x: 2.5, y: 2.5, width: 13, height: 13))
            p.move(to: CGPoint(x: 9, y: 5.5))
            p.addLine(to: CGPoint(x: 9, y: 9))
            p.addLine(to: CGPoint(x: 11.5, y: 10.5))

        case .hammer:
            p.move(to: CGPoint(x: 3, y: 15))
            p.addLine(to: CGPoint(x: 10, y: 8))
            p.move(to: CGPoint(x: 7.5, y: 5.5))
            p.addLine(to: CGPoint(x: 10.5, y: 2.5))
            p.addLine(to: CGPoint(x: 15.5, y: 7.5))
            p.addLine(to: CGPoint(x: 12.5, y: 10.5))
            p.closeSubpath()

        case .braces:
            p.move(to: CGPoint(x: 7, y: 2.5))
            p.addCurve(to: CGPoint(x: 3, y: 9), control1: CGPoint(x: 3.5, y: 2.5), control2: CGPoint(x: 6.5, y: 9))
            p.addCurve(to: CGPoint(x: 7, y: 15.5), control1: CGPoint(x: 6.5, y: 9), control2: CGPoint(x: 3.5, y: 15.5))
            p.move(to: CGPoint(x: 11, y: 2.5))
            p.addCurve(to: CGPoint(x: 15, y: 9), control1: CGPoint(x: 14.5, y: 2.5), control2: CGPoint(x: 11.5, y: 9))
            p.addCurve(to: CGPoint(x: 11, y: 15.5), control1: CGPoint(x: 11.5, y: 9), control2: CGPoint(x: 14.5, y: 15.5))

        case .terminal:
            p.addRoundedRect(in: CGRect(x: 2.5, y: 3, width: 13, height: 12), cornerSize: CGSize(width: 1.8, height: 1.8))
            p.move(to: CGPoint(x: 5.5, y: 6.8))
            p.addLine(to: CGPoint(x: 8, y: 9))
            p.addLine(to: CGPoint(x: 5.5, y: 11.2))
            p.move(to: CGPoint(x: 9.5, y: 11.5))
            p.addLine(to: CGPoint(x: 12.5, y: 11.5))

        case .play:
            p.move(to: CGPoint(x: 5.5, y: 3.5))
            p.addLine(to: CGPoint(x: 14, y: 9))
            p.addLine(to: CGPoint(x: 5.5, y: 14.5))
            p.closeSubpath()

        case .branch:
            p.addEllipse(in: CGRect(x: 3.2, y: 2.2, width: 3.6, height: 3.6))
            p.addEllipse(in: CGRect(x: 3.2, y: 12.2, width: 3.6, height: 3.6))
            p.addEllipse(in: CGRect(x: 11.2, y: 4.2, width: 3.6, height: 3.6))
            p.move(to: CGPoint(x: 5, y: 5.8))
            p.addLine(to: CGPoint(x: 5, y: 12.2))
            p.move(to: CGPoint(x: 13, y: 7.8))
            p.addCurve(to: CGPoint(x: 5, y: 12.2), control1: CGPoint(x: 13, y: 11), control2: CGPoint(x: 7, y: 9.5))
        }

        return p
    }
}

private struct LineGlyphShape: Shape {
    let glyph: LineGlyph

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 18
        return glyph.path.applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: scale, y: scale)
        )
    }
}

/// A line icon. Neutral at rest, accent when selected, and white on a filled
/// selection so it stays readable whatever the system's selection color is.
struct LineGlyphView: View {
    let glyph: LineGlyph
    var isSelected: Bool = false

    @Environment(\.backgroundProminence) private var backgroundProminence

    private var color: Color {
        if backgroundProminence == .increased { return .white }
        return isSelected ? Color.daAccent : Color.daTertiaryText
    }

    var body: some View {
        LineGlyphShape(glyph: glyph)
            .stroke(color, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }
}
