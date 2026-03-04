import SwiftUI

extension Font {
    static func daFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: - Predefined Font Styles
    static let daSmallLabel = daFont(size: 10, weight: .regular)
    static let daSmallLabelSemiBold = daFont(size: 10, weight: .semibold)
    static let daFileExtension = daFont(size: 11, weight: .regular)
    static let daFileExtensionMedium = daFont(size: 11, weight: .medium)
    static let daTechTag = daFont(size: 11.5, weight: .medium)
    static let daBody = daFont(size: 12, weight: .regular)
    static let daBodyMedium = daFont(size: 12, weight: .medium)
    static let daBodySemiBold = daFont(size: 12, weight: .semibold)
    static let daSectionHeader = daFont(size: 13, weight: .regular)
    static let daSectionHeaderSemiBold = daFont(size: 13, weight: .semibold)
    static let daSectionHeaderLight = daFont(size: 13, weight: .light)
    static let daSubSectionSemiBold = daFont(size: 14, weight: .semibold)
    static let daSectionTitle = daFont(size: 15, weight: .semibold)
    static let daIconText = daFont(size: 16, weight: .bold)
    static let daProjectTitle = daFont(size: 22, weight: .bold)

    // MARK: - Card specific
    static let daCardTag = daFont(size: 9, weight: .regular)
    static let daCardIcon = daFont(size: 10, weight: .bold)
}
