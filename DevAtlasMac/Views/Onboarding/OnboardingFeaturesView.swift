import SwiftUI

struct OnboardingFeaturesView: View {
    let onNext: () -> Void
    let onPrevious: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.daBlue)
                    .frame(width: 64, height: 64)
                    .background(Color.daBlue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text("onboarding.features.title".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.daPrimaryText)
                
                Text("onboarding.discoverProjects".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Spacer().frame(height: 28)
            
            // Features Card
            VStack(spacing: 0) {
                featureRow(icon: "magnifyingglass", title: "onboarding.features.autoScan.title".localized, description: "onboarding.features.autoScan.subtitle".localized, color: Color.daBlue)
                Divider().padding(.horizontal, 16)
                featureRow(icon: "line.3.horizontal.decrease.circle.fill", title: "onboarding.features.smartFilters.title".localized, description: "onboarding.features.smartFilters.subtitle".localized, color: Color.daEmerald)
                Divider().padding(.horizontal, 16)
                featureRow(icon: "text.magnifyingglass", title: "onboarding.features.search.title".localized, description: "onboarding.features.search.subtitle".localized, color: Color.daBlue)
                Divider().padding(.horizontal, 16)
                featureRow(icon: "clock.arrow.circlepath", title: "onboarding.features.recentActivity.title".localized, description: "onboarding.features.recentActivity.subtitle".localized, color: Color.daTertiaryText)
            }
            .background(Color.daWhite)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.daBorder.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            
            // Category Pills
            HStack(spacing: 8) {
                ForEach(["sidebar.web", "sidebar.desktop", "sidebar.mobile", "sidebar.cloud"], id: \.self) { key in
                    Text(key.localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.daSecondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.daBlue.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 16)
            
            Spacer()
            
            // Buttons
            OnboardingNavButtons(onNext: onNext, onPrevious: onPrevious)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.daOffWhite)
    }
    
    private func featureRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daTertiaryText)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

#Preview {
    OnboardingFeaturesView(onNext: {}, onPrevious: {})
}
