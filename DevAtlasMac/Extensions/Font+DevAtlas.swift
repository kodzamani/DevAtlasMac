import SwiftUI

extension Font {
    static func daFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: - Predefined Font Styles
    static let daSmallLabel = daFont(size: 10, weight: .regular)
    static let daSmallLabelSemiBold = daFont(size: 10, weight: .semibold)
    static let daBody = daFont(size: 12, weight: .regular)
    static let daBodyMedium = daFont(size: 12, weight: .medium)
    static let daBodySemiBold = daFont(size: 12, weight: .semibold)
    static let daSectionHeader = daFont(size: 13, weight: .regular)
    static let daSectionHeaderSemiBold = daFont(size: 13, weight: .semibold)
    static let daSectionTitle = daFont(size: 15, weight: .semibold)
}
