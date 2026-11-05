import SwiftUI

struct OnboardingWelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                logo

                Text("app.name".localized)
                    .font(.system(size: 38, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Color.daPrimaryText)
                    .accessibilityAddTraits(.isHeader)

                Text("app.tagline".localized)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.daSecondaryText)
                    .multilineTextAlignment(.center)
            }

            HStack(alignment: .top, spacing: 12) {
                card(.folder, "onboarding.features.feature1.title", "onboarding.features.feature1.subtitle")
                card(.bars, "onboarding.features.feature2.title", "onboarding.features.feature2.subtitle")
                card(.notebook, "onboarding.features.feature3.title", "onboarding.features.feature3.subtitle")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// The logo over a blurred copy of itself, so its own colors make the glow.
    private var logo: some View {
        Image("logo_brand")
            .resizable()
            .scaledToFit()
            .frame(width: 168, height: 168)
            .background {
                Image("logo_brand")
                    .resizable()
                    .scaledToFit()
                    .blur(radius: 30)
                    .opacity(0.5)
            }
            .accessibilityHidden(true)
    }

    private func card(_ glyph: LineGlyph, _ titleKey: String, _ subtitleKey: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OnboardingGlyphTile(glyph: glyph)

            Text(titleKey.localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.daPrimaryText)

            Text(subtitleKey.localized)
                .font(.system(size: 12))
                .foregroundStyle(Color.daTertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .daCardSurface()
    }
}

#Preview {
    OnboardingWelcomeView()
}
