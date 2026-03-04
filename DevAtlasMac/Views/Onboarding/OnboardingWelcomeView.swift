import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo & Title
            VStack(spacing: 16) {
                Image("logo_brand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 256, height: 256)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
                
                VStack(spacing: 6) {
                    Text("app.name".localized)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.daPrimaryText)
                    
                    Text("app.tagline".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.daSecondaryText)
                }
            }
            
            Spacer().frame(height: 36)
            
            // Feature List Card
            VStack(spacing: 0) {
                featureRow(icon: "folder.fill", title: "onboarding.features.feature1.title".localized, subtitle: "onboarding.features.feature1.subtitle".localized, color: Color.daBlue)
                
                Divider().padding(.horizontal, 16)
                
                featureRow(icon: "chart.bar.fill", title: "onboarding.features.feature2.title".localized, subtitle: "onboarding.features.feature2.subtitle".localized, color: Color.daEmerald)
                
                Divider().padding(.horizontal, 16)
                
                featureRow(icon: "note.text", title: "onboarding.features.feature3.title".localized, subtitle: "onboarding.features.feature3.subtitle".localized, color: Color.daBlue)
            }
            .background(Color.daWhite)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.daBorder.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            
            Spacer()
            
            // Buttons
            OnboardingButtons(
                primaryTitle: "onboarding.welcome.getStarted".localized,
                primaryAction: onNext,
                secondaryTitle: "onboarding.welcome.skip".localized,
                secondaryAction: onSkip
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.daOffWhite)
    }
    
    private func featureRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daTertiaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.daTertiaryText.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    OnboardingWelcomeView(onNext: {}, onSkip: {})
}
