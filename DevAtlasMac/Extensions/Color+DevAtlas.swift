import SwiftUI

extension Color {
    private static var isDark: Bool {
        UserDefaults.standard.bool(forKey: "isDarkMode")
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
        case "blue": return isDark ? Color(hex: "60A5FA") : Color(hex: "1D4ED8")
        case "purple": return isDark ? Color(hex: "A78BFA") : Color(hex: "6D28D9")
        case "pink": return isDark ? Color(hex: "F472B6") : Color(hex: "BE185D")
        case "red": return isDark ? Color(hex: "F87171") : Color(hex: "B91C1C")
        case "orange": return isDark ? Color(hex: "FB923C") : Color(hex: "C2410C")
        case "yellow": return isDark ? Color(hex: "FACC15") : Color(hex: "A16207")
        case "green": return isDark ? Color(hex: "4ADE80") : Color(hex: "15803D")
        case "teal": return isDark ? Color(hex: "2DD4BF") : Color(hex: "0F766E")
        case "indigo": return isDark ? Color(hex: "818CF8") : Color(hex: "3730A3")
        case "cyan": return isDark ? Color(hex: "22D3EE") : Color(hex: "0891B2")
        default: return isDark ? Color(hex: "60A5FA") : Color(hex: "1D4ED8")
        }
    }
    
    /// Light variant of accent color for backgrounds
    static var daAccentLight: Color {
        let savedAccent = UserDefaults.standard.string(forKey: "appAccentColor") ?? AppAccentColor.blue.rawValue
        switch savedAccent {
        case "blue": return isDark ? Color(hex: "1E293B") : Color(hex: "EFF6FF")
        case "purple": return isDark ? Color(hex: "2E1065") : Color(hex: "FAF5FF")
        case "pink": return isDark ? Color(hex: "500724") : Color(hex: "FDF2F8")
        case "red": return isDark ? Color(hex: "450A0A") : Color(hex: "FEF2F2")
        case "orange": return isDark ? Color(hex: "431407") : Color(hex: "FFF7ED")
        case "yellow": return isDark ? Color(hex: "422006") : Color(hex: "FEFCE8")
        case "green": return isDark ? Color(hex: "052E16") : Color(hex: "F0FDF4")
        case "teal": return isDark ? Color(hex: "042F2E") : Color(hex: "F0FDFA")
        case "indigo": return isDark ? Color(hex: "1E1B4B") : Color(hex: "EEF2FF")
        case "cyan": return isDark ? Color(hex: "083344") : Color(hex: "ECFEFF")
        default: return isDark ? Color(hex: "1E293B") : Color(hex: "EFF6FF")
        }
    }
    
    /// Very light variant for subtle backgrounds
    static var daAccentVeryLight: Color {
        let savedAccent = UserDefaults.standard.string(forKey: "appAccentColor") ?? AppAccentColor.blue.rawValue
        switch savedAccent {
        case "blue": return isDark ? Color(hex: "1E3A5F") : Color(hex: "DBEAFE")
        case "purple": return isDark ? Color(hex: "3B0764") : Color(hex: "F3E8FF")
        case "pink": return isDark ? Color(hex: "831843") : Color(hex: "FCE7F3")
        case "red": return isDark ? Color(hex: "7F1D1D") : Color(hex: "FEE2E2")
        case "orange": return isDark ? Color(hex: "7C2D12") : Color(hex: "FFEDD5")
        case "yellow": return isDark ? Color(hex: "713F12") : Color(hex: "FEF9C3")
        case "green": return isDark ? Color(hex: "14532D") : Color(hex: "DCFCE7")
        case "teal": return isDark ? Color(hex: "134E4A") : Color(hex: "CCFBF1")
        case "indigo": return isDark ? Color(hex: "312E81") : Color(hex: "E0E7FF")
        case "cyan": return isDark ? Color(hex: "164E63") : Color(hex: "CFFAFE")
        default: return isDark ? Color(hex: "1E3A5F") : Color(hex: "DBEAFE")
        }
    }

    // MARK: - Primary Colors
    static var daPrimaryText: Color { isDark ? Color(hex: "F9FAFB") : Color(hex: "111827") }
    static var daSecondaryText: Color { isDark ? Color(hex: "D1D5DB") : Color(hex: "374151") }
    static var daTertiaryText: Color { isDark ? Color(hex: "9CA3AF") : Color(hex: "6B7280") }
    static var daMutedText: Color { isDark ? Color(hex: "6B7280") : Color(hex: "9CA3AF") }

    // MARK: - Accent Colors
    static var daBlue: Color { Color(hex: "3B82F6") }
    static var daDarkBlue: Color { isDark ? Color(hex: "60A5FA") : Color(hex: "1D4ED8") }
    static var daGreen: Color { Color(hex: "22C55E") }
    static var daEmerald: Color { Color(hex: "10B981") }
    static var daDarkGreen: Color { isDark ? Color(hex: "4ADE80") : Color(hex: "15803D") }
    static var daOrange: Color { Color(hex: "F97316") }

    // MARK: - Background Colors
    static var daWhite: Color { isDark ? Color(hex: "131313") : Color(hex: "FFFFFF") }
    static var daOffWhite: Color { isDark ? Color(hex: "000000") : Color(hex: "F8F8F8") }
    static var daLightGray: Color { isDark ? Color(hex: "1C1C1E") : Color(hex: "F3F4F6") }
    static var daVeryLightGray: Color { isDark ? Color(hex: "0A0A0A") : Color(hex: "F9FAFB") }
    static var daBorder: Color { isDark ? Color(hex: "2A2A2A") : Color(hex: "E5E7EB") }
    static var daLightBlue: Color { isDark ? Color(hex: "1E293B") : Color(hex: "EFF6FF") }
    static var daLightGreen: Color { isDark ? Color(hex: "14532D") : Color(hex: "DCFCE7") }
    static var daSeparator: Color { isDark ? Color(hex: "333333") : Color(hex: "D1D5DB") }
    static var backgroundSecondary: Color { isDark ? Color(hex: "1A1A1A") : Color(hex: "F5F5F5") }

    // MARK: - Icon Grid Colors (Dynamic based on accent color)
    static var daIconGridLight: Color {
        let savedAccent = UserDefaults.standard.string(forKey: "appAccentColor") ?? AppAccentColor.blue.rawValue
        switch savedAccent {
        case "blue": return isDark ? Color(hex: "1E40AF") : Color(hex: "BFDBFE")
        case "purple": return isDark ? Color(hex: "5B21B6") : Color(hex: "E9D5FF")
        case "pink": return isDark ? Color(hex: "9D174D") : Color(hex: "FCE7F3")
        case "red": return isDark ? Color(hex: "991B1B") : Color(hex: "FEE2E2")
        case "orange": return isDark ? Color(hex: "9A3412") : Color(hex: "FFEDD5")
        case "yellow": return isDark ? Color(hex: "854D0E") : Color(hex: "FEF9C3")
        case "green": return isDark ? Color(hex: "166534") : Color(hex: "DCFCE7")
        case "teal": return isDark ? Color(hex: "115E59") : Color(hex: "CCFBF1")
        case "indigo": return isDark ? Color(hex: "3730A3") : Color(hex: "E0E7FF")
        case "cyan": return isDark ? Color(hex: "164E63") : Color(hex: "CFFAFE")
        default: return isDark ? Color(hex: "1E40AF") : Color(hex: "BFDBFE")
        }
    }
    
    static var daIconGridDark: Color {
        let savedAccent = UserDefaults.standard.string(forKey: "appAccentColor") ?? AppAccentColor.blue.rawValue
        switch savedAccent {
        case "blue": return isDark ? Color(hex: "2563EB") : Color(hex: "93C5FD")
        case "purple": return isDark ? Color(hex: "7C3AED") : Color(hex: "C4B5FD")
        case "pink": return isDark ? Color(hex: "DB2777") : Color(hex: "F9A8D4")
        case "red": return isDark ? Color(hex: "DC2626") : Color(hex: "FCA5A5")
        case "orange": return isDark ? Color(hex: "EA580C") : Color(hex: "FDBA74")
        case "yellow": return isDark ? Color(hex: "CA8A04") : Color(hex: "FDE047")
        case "green": return isDark ? Color(hex: "16A34A") : Color(hex: "86EFAC")
        case "teal": return isDark ? Color(hex: "0D9488") : Color(hex: "5EEAD4")
        case "indigo": return isDark ? Color(hex: "4F46E5") : Color(hex: "A5B4FC")
        case "cyan": return isDark ? Color(hex: "0891B2") : Color(hex: "67E8F9")
        default: return isDark ? Color(hex: "2563EB") : Color(hex: "93C5FD")
        }
    }

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
