import SwiftUI

struct OnboardingAppearanceView: View {
    @Bindable var appViewModel: AppViewModel
    let onComplete: () -> Void
    let onPrevious: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 10) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.daAccent)
                    .frame(width: 64, height: 64)
                    .background(Color.daAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text("onboarding.appearance.title".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.daPrimaryText)
                
                Text("onboarding.appearance.subtitle".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
            }
            
            Spacer().frame(height: 32)
            
            // Theme Selection
            HStack(spacing: 16) {
                appearanceCard(
                    title: "onboarding.appearance.light".localized,
                    icon: "sun.max.fill",
                    isSelected: !appViewModel.isDarkMode,
                    action: { appViewModel.isDarkMode = false }
                )
                
                appearanceCard(
                    title: "onboarding.appearance.dark".localized,
                    icon: "moon.fill",
                    isSelected: appViewModel.isDarkMode,
                    action: { appViewModel.isDarkMode = true }
                )
            }
            
            Spacer().frame(height: 28)
            
            // Ready badge
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.daEmerald)
                Text("onboarding.appearance.allSet".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.daEmerald.opacity(0.08))
            .clipShape(Capsule())
            
            Spacer()
            
            // Buttons
            OnboardingButtons(
                primaryTitle: "onboarding.appearance.start".localized,
                primaryAction: onComplete,
                secondaryTitle: "onboarding.appearance.back".localized,
                secondaryAction: onPrevious,
                primaryIcon: "arrow.right",
                primaryGradient: true
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.daOffWhite)
    }
    
    private func appearanceCard(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSelected ? Color.daAccent : Color.daTertiaryText)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.daPrimaryText : Color.daSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color.daWhite)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.daAccent : Color.daBorder.opacity(0.6), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Color.daAccent.opacity(0.12) : Color.black.opacity(0.04), radius: isSelected ? 12 : 8, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingAppearanceView(appViewModel: AppViewModel(), onComplete: {}, onPrevious: {})
}
