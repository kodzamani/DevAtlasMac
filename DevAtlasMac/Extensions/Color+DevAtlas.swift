import SwiftUI

extension Color {
    /// Resolves against the appearance it is drawn in, so a theme change recolors views
    /// without rebuilding them.
    private static func adaptive(dark: Color, light: Color) -> Color {
        let darkColor = NSColor(dark)
        let lightColor = NSColor(light)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkColor : lightColor
        })
    }
    
    // MARK: - Dynamic Accent Colors
    /// Returns the currently selected accent color from UserDefaults
    static var daAccent: Color {
        let savedAccent = UserDefaults.standard.string(forKey: "appAccentColor") ?? AppAccentColor.blue.rawValue
        return AppAccentColor(rawValue: savedAccent)?.color ?? .blue
    }
    
    /// Darker variant of accent color for text
    static var daAccentDark: Color {
        let savedAccent = UserDefaults.standard.string(forKey: "appAccentColor") ?? AppAccentColor.blue.rawValue
        switch savedAccent {
        case "blue": return adaptive(dark: Color(hex: "60A5FA"), light: Color(hex: "1D4ED8"))
        case "purple": return adaptive(dark: Color(hex: "A78BFA"), light: Color(hex: "6D28D9"))
        case "pink": return adaptive(dark: Color(hex: "F472B6"), light: Color(hex: "BE185D"))
        case "red": return adaptive(dark: Color(hex: "F87171"), light: Color(hex: "B91C1C"))
        case "orange": return adaptive(dark: Color(hex: "FB923C"), light: Color(hex: "C2410C"))
        case "yellow": return adaptive(dark: Color(hex: "FACC15"), light: Color(hex: "A16207"))
        case "green": return adaptive(dark: Color(hex: "4ADE80"), light: Color(hex: "15803D"))
        case "teal": return adaptive(dark: Color(hex: "2DD4BF"), light: Color(hex: "0F766E"))
        case "indigo": return adaptive(dark: Color(hex: "818CF8"), light: Color(hex: "3730A3"))
        case "cyan": return adaptive(dark: Color(hex: "22D3EE"), light: Color(hex: "0891B2"))
        default: return adaptive(dark: Color(hex: "60A5FA"), light: Color(hex: "1D4ED8"))
        }
    }

    // MARK: - Primary Colors
    static var daPrimaryText: Color { adaptive(dark: Color(hex: "F5F5F7"), light: Color(hex: "1D1D1F")) }
    static var daSecondaryText: Color { adaptive(dark: Color(hex: "C7C7CC"), light: Color(hex: "3A3A3C")) }
    static var daTertiaryText: Color { adaptive(dark: Color(hex: "98989D"), light: Color(hex: "6E6E73")) }
    static var daMutedText: Color { adaptive(dark: Color(hex: "6E6E73"), light: Color(hex: "8E8E93")) }

    // MARK: - Accent Colors
    static var daBlue: Color { Color(hex: "3B82F6") }
    static var daDarkBlue: Color { adaptive(dark: Color(hex: "60A5FA"), light: Color(hex: "1D4ED8")) }
    static var daGreen: Color { Color(hex: "22C55E") }
    static var daEmerald: Color { Color(hex: "10B981") }
    static var daDarkGreen: Color { adaptive(dark: Color(hex: "4ADE80"), light: Color(hex: "15803D")) }
    static var daOrange: Color { Color(hex: "F97316") }

    // MARK: - Background Colors
    static var daWhite: Color { adaptive(dark: Color(hex: "262628"), light: Color(hex: "FFFFFF")) }
    /// Translucent card fill for use on the Metal surface.
    static var daCard: Color { adaptive(dark: Color.white.opacity(0.045), light: Color.white.opacity(0.22)) }
    /// Hairline around a `daCard` surface.
    static var daCardEdge: Color { adaptive(dark: Color.white.opacity(0.07), light: Color.black.opacity(0.06)) }
    static var daOffWhite: Color { adaptive(dark: Color(hex: "1A1A1C"), light: Color(hex: "F5F5F7")) }
    static var daLightGray: Color { adaptive(dark: Color(hex: "2E2E30"), light: Color(hex: "F0F0F3")) }
    /// Opaque, slightly toned surface for the chat composer and popovers.
    static var daChatSurface: Color { adaptive(dark: Color(hex: "1E1E20"), light: Color(hex: "ECECF0")) }
    static var daBorder: Color { adaptive(dark: Color(hex: "38383A"), light: Color(hex: "E3E3E6")) }
    /// Docker's brand blue, lifted for dark surfaces.
    static var daDocker: Color { adaptive(dark: Color(hex: "4C8DFF"), light: Color(hex: "1D63ED")) }
    static var daSeparator: Color { adaptive(dark: Color(hex: "48484A"), light: Color(hex: "D1D1D6")) }

    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
