import SwiftUI

struct OnboardingQuickActionsView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 12) {
                card(.hammer, "Xcode", "onboarding.quickActions.xcode".localized)
                card(.braces, "VS Code", "onboarding.quickActions.vscode".localized)
                card(.terminal, "Terminal", "onboarding.quickActions.terminal".localized)
                card(.folder, "Finder", "onboarding.quickActions.finder".localized)
            }

            HStack(spacing: 8) {
                chip(.play, "onboarding.quickActions.runProjects".localized)
                chip(.bars, "onboarding.quickActions.analyzeCode".localized)
            }
        }
    }

    private func card(_ glyph: LineGlyph, _ title: String, _ subtitle: String) -> some View {
        OnboardingFeatureRow(glyph: glyph, title: title, subtitle: subtitle)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .daCardSurface()
    }

    private func chip(_ glyph: LineGlyph, _ text: String) -> some View {
        HStack(spacing: 6) {
            LineGlyphView(glyph: glyph, isSelected: true)
                .scaleEffect(0.8)
                .frame(width: 16, height: 16)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.daSecondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .daCardSurface(cornerRadius: 8)
    }
}

#Preview {
    OnboardingQuickActionsView()
}
