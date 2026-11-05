import SwiftUI

/// Equal-width steps keep the connecting line and labels aligned in every language.
struct OnboardingStepper: View {
    let currentPage: OnboardingPage
    let selectPage: (OnboardingPage) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(OnboardingPage.allCases, id: \.self) { page in
                OnboardingStepButton(
                    page: page,
                    currentPage: currentPage,
                    action: { selectPage(page) }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .background(alignment: .top) {
            GeometryReader { proxy in
                let inset = proxy.size.width / CGFloat(OnboardingPage.allCases.count * 2)
                let trackWidth = max(0, proxy.size.width - inset * 2)
                let progress = CGFloat(currentPage.rawValue) / CGFloat(OnboardingPage.allCases.count - 1)

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.daBorder)
                    Capsule().fill(Color.daAccent).frame(width: trackWidth * progress)
                }
                .frame(width: trackWidth, height: 2)
                .offset(x: inset, y: 15)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct OnboardingStepButton: View {
    let page: OnboardingPage
    let currentPage: OnboardingPage
    let action: () -> Void

    @State private var isHovered = false

    private var isCurrent: Bool { page == currentPage }
    private var isDone: Bool { page.rawValue < currentPage.rawValue }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.daOffWhite)
                    Circle()
                        .fill(Color.daAccent.opacity(isCurrent ? 1 : (isDone ? 0.12 : (isHovered ? 0.06 : 0))))
                    Circle()
                        .strokeBorder(isCurrent || isDone ? Color.daAccent : Color.daSeparator, lineWidth: isCurrent ? 0 : 1)

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.daAccentDark)
                    } else {
                        Text("\(page.rawValue + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(isCurrent ? Color.white : Color.daTertiaryText)
                    }
                }
                .frame(width: 26, height: 26)
                .padding(3)
                .background {
                    Circle()
                        .strokeBorder(Color.daAccent.opacity(isCurrent ? 0.2 : 0), lineWidth: 2)
                }

                Text(page.stepTitle)
                    .font(.system(size: 11, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? Color.daAccentDark : (isDone ? Color.daSecondaryText : Color.daTertiaryText))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .top)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(page.stepTitle)
        .accessibilityValue(accessibilityStatus)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var accessibilityStatus: String {
        let counter = "onboarding.stepCounter".localized(page.rawValue + 1, OnboardingPage.allCases.count)
        return isDone ? "\(counter), \("common.done".localized)" : counter
    }
}

/// A line glyph on a soft accent tile.
struct OnboardingGlyphTile: View {
    let glyph: LineGlyph

    var body: some View {
        LineGlyphView(glyph: glyph, isSelected: true)
            .frame(width: 34, height: 34)
            .background(Color.daAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Tile, title and description, used for the rows and cards of the onboarding pages.
struct OnboardingFeatureRow: View {
    let glyph: LineGlyph
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            OnboardingGlyphTile(glyph: glyph)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
