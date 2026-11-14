import SwiftUI

/// Line icons for the Chat tab, drawn by hand on an 18×18 grid (no SF Symbols).
enum ChatGlyph {
    case grid, hammer, code, terminal, folder, copy, play, stop, branch, bars, box
    case arrowUpCircle, scissors, drive, trash, doc, notePlus, note, checklist
    case clock, compose, pie, refresh, help, arrowUp, close, check, warning, info
    case checkCircle, xCircle, chevronRight, chevronDown, arrowUpRight, external
    case pencil, sparkles, chat, lines

    /// Solid shapes are filled instead of stroked.
    fileprivate var isFilled: Bool { self == .play || self == .stop }

    fileprivate var path: Path {
        var p = Path()
        let c = CGSize(width: 1.6, height: 1.6)

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        func line(_ a: CGPoint, _ b: CGPoint) { p.move(to: a); p.addLine(to: b) }
        func dot(_ x: CGFloat, _ y: CGFloat) { p.move(to: pt(x, y)); p.addLine(to: pt(x, y + 0.05)) }
        func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ from: Double, _ to: Double) {
            let steps = 24
            for i in 0...steps {
                let a = (from + (to - from) * Double(i) / Double(steps)) * .pi / 180
                let point = pt(cx + r * CGFloat(cos(a)), cy + r * CGFloat(sin(a)))
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
        }
        func circle() { p.addEllipse(in: CGRect(x: 2.5, y: 2.5, width: 13, height: 13)) }

        switch self {
        case .grid:
            for (x, y) in [(2.5, 2.5), (10.5, 2.5), (2.5, 10.5), (10.5, 10.5)] {
                p.addRoundedRect(in: CGRect(x: x, y: y, width: 5, height: 5), cornerSize: CGSize(width: 1.4, height: 1.4))
            }

        case .hammer:
            line(pt(3, 15), pt(10, 8))
            p.move(to: pt(7.5, 5.5))
            p.addLine(to: pt(10.5, 2.5))
            p.addLine(to: pt(15.5, 7.5))
            p.addLine(to: pt(12.5, 10.5))
            p.closeSubpath()

        case .code:
            p.move(to: pt(6.5, 5)); p.addLine(to: pt(2.5, 9)); p.addLine(to: pt(6.5, 13))
            p.move(to: pt(11.5, 5)); p.addLine(to: pt(15.5, 9)); p.addLine(to: pt(11.5, 13))
            line(pt(10, 3.5), pt(8, 14.5))

        case .terminal:
            p.addRoundedRect(in: CGRect(x: 2.5, y: 3, width: 13, height: 12), cornerSize: c)
            p.move(to: pt(5.5, 6.8)); p.addLine(to: pt(8, 9)); p.addLine(to: pt(5.5, 11.2))
            line(pt(9.5, 11.5), pt(12.5, 11.5))

        case .folder:
            p.move(to: pt(2.5, 5))
            p.addQuadCurve(to: pt(4, 3.5), control: pt(2.5, 3.5))
            p.addLine(to: pt(6.8, 3.5))
            p.addLine(to: pt(8.5, 5.5))
            p.addLine(to: pt(14, 5.5))
            p.addQuadCurve(to: pt(15.5, 7), control: pt(15.5, 5.5))
            p.addLine(to: pt(15.5, 13))
            p.addQuadCurve(to: pt(14, 14.5), control: pt(15.5, 14.5))
            p.addLine(to: pt(4, 14.5))
            p.addQuadCurve(to: pt(2.5, 13), control: pt(2.5, 14.5))
            p.closeSubpath()

        case .copy:
            p.addRoundedRect(in: CGRect(x: 7, y: 7, width: 8.5, height: 8.5), cornerSize: c)
            p.move(to: pt(11.5, 6))
            p.addLine(to: pt(11.5, 4.6))
            p.addQuadCurve(to: pt(10, 3), control: pt(11.5, 3))
            p.addLine(to: pt(4.6, 3))
            p.addQuadCurve(to: pt(3, 4.6), control: pt(3, 3))
            p.addLine(to: pt(3, 10))
            p.addQuadCurve(to: pt(4.6, 11.5), control: pt(3, 11.5))
            p.addLine(to: pt(6, 11.5))

        case .play:
            p.move(to: pt(5.5, 3.5)); p.addLine(to: pt(14, 9)); p.addLine(to: pt(5.5, 14.5)); p.closeSubpath()

        case .stop:
            p.addRoundedRect(in: CGRect(x: 4.5, y: 4.5, width: 9, height: 9), cornerSize: CGSize(width: 2, height: 2))

        case .branch:
            p.addEllipse(in: CGRect(x: 3.2, y: 2.2, width: 3.6, height: 3.6))
            p.addEllipse(in: CGRect(x: 3.2, y: 12.2, width: 3.6, height: 3.6))
            p.addEllipse(in: CGRect(x: 11.2, y: 4.2, width: 3.6, height: 3.6))
            line(pt(5, 5.8), pt(5, 12.2))
            p.move(to: pt(13, 7.8))
            p.addCurve(to: pt(5, 12.2), control1: pt(13, 11), control2: pt(7, 9.5))

        case .bars:
            let r = CGSize(width: 0.9, height: 0.9)
            p.addRoundedRect(in: CGRect(x: 2.5, y: 9.5, width: 3.4, height: 6), cornerSize: r)
            p.addRoundedRect(in: CGRect(x: 7.3, y: 2.5, width: 3.4, height: 13), cornerSize: r)
            p.addRoundedRect(in: CGRect(x: 12.1, y: 6, width: 3.4, height: 9.5), cornerSize: r)

        case .box:
            p.move(to: pt(9, 2.5)); p.addLine(to: pt(15, 5.8)); p.addLine(to: pt(15, 12.2))
            p.addLine(to: pt(9, 15.5)); p.addLine(to: pt(3, 12.2)); p.addLine(to: pt(3, 5.8)); p.closeSubpath()
            p.move(to: pt(3, 5.8)); p.addLine(to: pt(9, 9)); p.addLine(to: pt(15, 5.8))
            line(pt(9, 9), pt(9, 15.5))

        case .arrowUpCircle:
            circle()
            line(pt(9, 12), pt(9, 6))
            p.move(to: pt(6.5, 8.3)); p.addLine(to: pt(9, 5.8)); p.addLine(to: pt(11.5, 8.3))

        case .scissors:
            p.addEllipse(in: CGRect(x: 2.5, y: 3.4, width: 3.4, height: 3.4))
            p.addEllipse(in: CGRect(x: 2.5, y: 11.2, width: 3.4, height: 3.4))
            line(pt(5.5, 6.2), pt(15.5, 13.5))
            line(pt(5.5, 11.8), pt(15.5, 4.5))

        case .drive:
            p.addRoundedRect(in: CGRect(x: 2.5, y: 9, width: 13, height: 5.5), cornerSize: CGSize(width: 2, height: 2))
            p.move(to: pt(2.5, 9)); p.addLine(to: pt(4.6, 3.8)); p.addLine(to: pt(13.4, 3.8)); p.addLine(to: pt(15.5, 9))
            dot(5.6, 11.7)

        case .trash:
            line(pt(3, 5), pt(15, 5))
            p.move(to: pt(7, 5)); p.addLine(to: pt(7, 3.8))
            p.addQuadCurve(to: pt(8, 2.8), control: pt(7, 2.8))
            p.addLine(to: pt(10, 2.8))
            p.addQuadCurve(to: pt(11, 3.8), control: pt(11, 2.8))
            p.addLine(to: pt(11, 5))
            p.move(to: pt(4.5, 5)); p.addLine(to: pt(5.2, 14))
            p.addQuadCurve(to: pt(6.7, 15.5), control: pt(5.3, 15.5))
            p.addLine(to: pt(11.3, 15.5))
            p.addQuadCurve(to: pt(12.8, 14), control: pt(12.7, 15.5))
            p.addLine(to: pt(13.5, 5))
            line(pt(7.6, 8), pt(7.8, 12.5))
            line(pt(10.4, 8), pt(10.2, 12.5))

        case .doc:
            p.move(to: pt(10.5, 2.5))
            p.addLine(to: pt(5, 2.5))
            p.addQuadCurve(to: pt(3.5, 4), control: pt(3.5, 2.5))
            p.addLine(to: pt(3.5, 14))
            p.addQuadCurve(to: pt(5, 15.5), control: pt(3.5, 15.5))
            p.addLine(to: pt(13, 15.5))
            p.addQuadCurve(to: pt(14.5, 14), control: pt(14.5, 15.5))
            p.addLine(to: pt(14.5, 6.5))
            p.addLine(to: pt(10.5, 2.5))
            p.addLine(to: pt(10.5, 6.5))
            p.addLine(to: pt(14.5, 6.5))
            line(pt(6.5, 10), pt(11.5, 10))
            line(pt(6.5, 12.6), pt(11.5, 12.6))

        case .notePlus:
            p.addRoundedRect(in: CGRect(x: 3.5, y: 2.5, width: 11, height: 13), cornerSize: CGSize(width: 1.8, height: 1.8))
            line(pt(9, 6), pt(9, 12))
            line(pt(6, 9), pt(12, 9))

        case .note:
            p.addRoundedRect(in: CGRect(x: 3.5, y: 2.5, width: 11, height: 13), cornerSize: CGSize(width: 1.8, height: 1.8))
            line(pt(6.5, 6.5), pt(11.5, 6.5))
            line(pt(6.5, 9.3), pt(11.5, 9.3))
            line(pt(6.5, 12), pt(9.5, 12))

        case .checklist:
            p.move(to: pt(2.5, 5)); p.addLine(to: pt(3.8, 6.3)); p.addLine(to: pt(6, 3.8))
            line(pt(8.5, 5), pt(15.5, 5))
            p.move(to: pt(2.5, 12)); p.addLine(to: pt(3.8, 13.3)); p.addLine(to: pt(6, 10.8))
            line(pt(8.5, 12), pt(15.5, 12))

        case .clock:
            circle()
            p.move(to: pt(9, 5.5)); p.addLine(to: pt(9, 9)); p.addLine(to: pt(11.5, 10.5))

        case .compose:
            p.move(to: pt(7.5, 3.5))
            p.addLine(to: pt(5, 3.5))
            p.addQuadCurve(to: pt(3, 5.5), control: pt(3, 3.5))
            p.addLine(to: pt(3, 13))
            p.addQuadCurve(to: pt(5, 15), control: pt(3, 15))
            p.addLine(to: pt(12.5, 15))
            p.addQuadCurve(to: pt(14.5, 13), control: pt(14.5, 15))
            p.addLine(to: pt(14.5, 10.5))
            p.move(to: pt(7, 11)); p.addLine(to: pt(7.4, 8.6)); p.addLine(to: pt(13.2, 2.8))
            p.addLine(to: pt(15.2, 4.8)); p.addLine(to: pt(9.4, 10.6)); p.closeSubpath()

        case .pie:
            circle()
            p.move(to: pt(9, 2.5)); p.addLine(to: pt(9, 9)); p.addLine(to: pt(13.6, 13.6))

        case .refresh:
            arc(9, 9, 6, 200, 340)
            p.move(to: pt(14.9, 3.6)); p.addLine(to: pt(14.9, 7.2)); p.addLine(to: pt(11.4, 7.2))
            arc(9, 9, 6, 20, 160)
            p.move(to: pt(3.1, 14.4)); p.addLine(to: pt(3.1, 10.8)); p.addLine(to: pt(6.6, 10.8))

        case .help:
            circle()
            p.move(to: pt(6.9, 7.2))
            p.addCurve(to: pt(9, 5.3), control1: pt(6.9, 6), control2: pt(7.8, 5.3))
            p.addCurve(to: pt(11.1, 7.2), control1: pt(10.2, 5.3), control2: pt(11.1, 6))
            p.addCurve(to: pt(9, 9.4), control1: pt(11.1, 8.4), control2: pt(9, 8.5))
            p.addLine(to: pt(9, 10.3))
            dot(9, 12.4)

        case .arrowUp:
            line(pt(9, 14.5), pt(9, 4))
            p.move(to: pt(4.5, 8.5)); p.addLine(to: pt(9, 4)); p.addLine(to: pt(13.5, 8.5))

        case .close:
            line(pt(4.5, 4.5), pt(13.5, 13.5))
            line(pt(13.5, 4.5), pt(4.5, 13.5))

        case .check:
            p.move(to: pt(3.5, 9.5)); p.addLine(to: pt(7.3, 13)); p.addLine(to: pt(14.5, 5))

        case .warning:
            p.move(to: pt(9, 2.8)); p.addLine(to: pt(15.8, 14.5)); p.addLine(to: pt(2.2, 14.5)); p.closeSubpath()
            line(pt(9, 7.5), pt(9, 10.8))
            dot(9, 12.6)

        case .info:
            circle()
            line(pt(9, 8.2), pt(9, 12.5))
            dot(9, 5.9)

        case .checkCircle:
            circle()
            p.move(to: pt(5.8, 9.2)); p.addLine(to: pt(8, 11.3)); p.addLine(to: pt(12.2, 6.8))

        case .xCircle:
            circle()
            line(pt(6.5, 6.5), pt(11.5, 11.5))
            line(pt(11.5, 6.5), pt(6.5, 11.5))

        case .chevronRight:
            p.move(to: pt(7, 4)); p.addLine(to: pt(12, 9)); p.addLine(to: pt(7, 14))

        case .chevronDown:
            p.move(to: pt(4, 7)); p.addLine(to: pt(9, 12)); p.addLine(to: pt(14, 7))

        case .arrowUpRight:
            line(pt(5, 13), pt(13, 5))
            p.move(to: pt(6.5, 5)); p.addLine(to: pt(13, 5)); p.addLine(to: pt(13, 11.5))

        case .external:
            p.move(to: pt(7.5, 3.5))
            p.addLine(to: pt(4.5, 3.5))
            p.addQuadCurve(to: pt(3, 5), control: pt(3, 3.5))
            p.addLine(to: pt(3, 13.5))
            p.addQuadCurve(to: pt(4.5, 15), control: pt(3, 15))
            p.addLine(to: pt(13, 15))
            p.addQuadCurve(to: pt(14.5, 13.5), control: pt(14.5, 15))
            p.addLine(to: pt(14.5, 10.5))
            line(pt(9, 9), pt(15, 3))
            p.move(to: pt(10.5, 3)); p.addLine(to: pt(15, 3)); p.addLine(to: pt(15, 7.5))

        case .pencil:
            p.move(to: pt(3.5, 14.5)); p.addLine(to: pt(4.2, 11)); p.addLine(to: pt(12, 3.2))
            p.addLine(to: pt(14.8, 6)); p.addLine(to: pt(7, 13.8)); p.closeSubpath()

        case .sparkles:
            p.move(to: pt(8, 4.5))
            p.addQuadCurve(to: pt(13.5, 10), control: pt(8.6, 9.4))
            p.addQuadCurve(to: pt(8, 15.5), control: pt(8.6, 10.6))
            p.addQuadCurve(to: pt(2.5, 10), control: pt(7.4, 10.6))
            p.addQuadCurve(to: pt(8, 4.5), control: pt(7.4, 9.4))
            p.closeSubpath()
            line(pt(14, 2), pt(14, 6))
            line(pt(12, 4), pt(16, 4))

        case .chat:
            p.move(to: pt(5, 3)); p.addLine(to: pt(13, 3))
            p.addQuadCurve(to: pt(15.5, 5.5), control: pt(15.5, 3))
            p.addLine(to: pt(15.5, 10))
            p.addQuadCurve(to: pt(13, 12.5), control: pt(15.5, 12.5))
            p.addLine(to: pt(8.5, 12.5)); p.addLine(to: pt(5.5, 15.5)); p.addLine(to: pt(5.5, 12.5)); p.addLine(to: pt(5, 12.5))
            p.addQuadCurve(to: pt(2.5, 10), control: pt(2.5, 12.5))
            p.addLine(to: pt(2.5, 5.5))
            p.addQuadCurve(to: pt(5, 3), control: pt(2.5, 3))
            p.closeSubpath()
            line(pt(6, 6.5), pt(12, 6.5))
            line(pt(6, 9.2), pt(10, 9.2))

        case .lines:
            line(pt(3, 5), pt(15, 5))
            line(pt(3, 9), pt(11, 9))
            line(pt(3, 13), pt(13, 13))
        }

        return p
    }
}

private struct ChatGlyphShape: Shape {
    let glyph: ChatGlyph

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 18
        return glyph.path.applying(CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: scale, y: scale))
    }
}

/// A Chat line icon. Takes its color from `foregroundStyle`.
struct ChatIcon: View {
    let glyph: ChatGlyph
    var size: CGFloat = 14
    /// Stroke width in points at 16pt; scales with `size`.
    var weight: CGFloat = 1.5

    init(_ glyph: ChatGlyph, size: CGFloat = 14, weight: CGFloat = 1.5) {
        self.glyph = glyph
        self.size = size
        self.weight = weight
    }

    var body: some View {
        let shape = ChatGlyphShape(glyph: glyph)
        Group {
            if glyph.isFilled {
                shape.fill(.foreground)
            } else {
                shape.stroke(.foreground, style: StrokeStyle(lineWidth: max(1, weight * size / 16), lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// An icon followed by text, in place of `Label(_, systemImage:)`.
struct ChatIconLabel: View {
    let title: String
    let glyph: ChatGlyph
    var iconSize: CGFloat = 12
    var spacing: CGFloat = 5

    var body: some View {
        HStack(spacing: spacing) {
            ChatIcon(glyph, size: iconSize)
            Text(title)
        }
    }
}
