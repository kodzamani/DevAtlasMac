import SwiftUI

struct OnboardingStatsNotebookView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            card(
                glyph: .bars,
                title: "onboarding.features.feature2.title".localized,
                items: ["onboarding.stats.languageBreakdown", "onboarding.stats.lineCountAnalysis", "onboarding.stats.timeInsights", "onboarding.stats.exportReports"]
            ) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array([0.35, 0.6, 0.45, 0.8, 0.55, 1.0, 0.7].enumerated()), id: \.offset) { index, height in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(Color.daAccent.opacity(index == 5 ? 0.9 : 0.28))
                            .frame(height: 56 * height)
                    }
                }
            }

            card(
                glyph: .notebook,
                title: "onboarding.features.feature3.title".localized,
                items: ["onboarding.notebook.projectDocs", "onboarding.notebook.organizeTags", "onboarding.notebook.linkProjects", "onboarding.notebook.markdownSupport"]
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array([0.45, 1.0, 0.85, 0.65].enumerated()), id: \.offset) { index, width in
                        GeometryReader { proxy in
                            Capsule()
                                .fill(index == 0 ? Color.daAccent.opacity(0.9) : Color.daAccent.opacity(0.22))
                                .frame(width: proxy.size.width * width)
                        }
                        .frame(height: index == 0 ? 8 : 6)
                    }
                }
                .frame(height: 56, alignment: .bottom)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func card<Illustration: View>(
        glyph: LineGlyph,
        title: String,
        items: [String],
        @ViewBuilder illustration: () -> Illustration
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            illustration()
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Divider()

            HStack(spacing: 10) {
                OnboardingGlyphTile(glyph: glyph)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { key in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.daAccent)
                        Text(key.localized)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.daSecondaryText)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .daCardSurface()
    }
}

#Preview {
    OnboardingStatsNotebookView()
}
