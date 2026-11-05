import SwiftUI

struct OnboardingFeaturesView: View {
    private let categories: [(key: String, tint: String)] = [
        ("sidebar.web", "3B82F6"),
        ("sidebar.desktop", "8B5CF6"),
        ("sidebar.mobile", "10B981"),
        ("sidebar.cloud", "06B6D4")
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(glyph: .scan, title: "onboarding.features.autoScan.title".localized, subtitle: "onboarding.features.autoScan.subtitle".localized)
                OnboardingFeatureRow(glyph: .funnel, title: "onboarding.features.smartFilters.title".localized, subtitle: "onboarding.features.smartFilters.subtitle".localized)
                OnboardingFeatureRow(glyph: .magnifier, title: "onboarding.features.search.title".localized, subtitle: "onboarding.features.search.subtitle".localized)
                OnboardingFeatureRow(glyph: .clock, title: "onboarding.features.recentActivity.title".localized, subtitle: "onboarding.features.recentActivity.subtitle".localized)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .daCardSurface()

            // Live Metal folders: move the pointer over them to see the light follow it.
            LazyVGrid(columns: [GridItem(.fixed(96)), GridItem(.fixed(96))], spacing: 14) {
                ForEach(categories, id: \.key) { category in
                    VStack(spacing: 6) {
                        FolderIconView(tint: Color(hex: category.tint), size: 68)
                        Text(category.key.localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.daSecondaryText)
                    }
                }
            }
            .padding(18)
            .frame(maxHeight: .infinity)
            .daCardSurface()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    OnboardingFeaturesView()
}
