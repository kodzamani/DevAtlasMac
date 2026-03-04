import SwiftUI

struct OnboardingQuickActionsView: View {
    let onNext: () -> Void
    let onPrevious: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.daEmerald)
                    .frame(width: 64, height: 64)
                    .background(Color.daEmerald.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text("onboarding.quickActions.title".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.daPrimaryText)
                
                Text("onboarding.lightningAccess".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Spacer().frame(height: 28)
            
            // Actions Card
            VStack(spacing: 0) {
                actionRow(icon: "hammer.fill", title: "Xcode", description: "onboarding.quickActions.xcode".localized, color: Color.daBlue)
                Divider().padding(.horizontal, 16)
                actionRow(icon: "curlybraces", title: "VS Code", description: "onboarding.quickActions.vscode".localized, color: Color(hex: "007ACC"))
                Divider().padding(.horizontal, 16)
                actionRow(icon: "terminal.fill", title: "Terminal", description: "onboarding.quickActions.terminal".localized, color: Color.daPrimaryText)
                Divider().padding(.horizontal, 16)
                actionRow(icon: "folder.fill", title: "Finder", description: "onboarding.quickActions.finder".localized, color: Color.daTertiaryText)
            }
            .background(Color.daWhite)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.daBorder.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            
            // Extra chips
            HStack(spacing: 8) {
                chip(icon: "play.fill", text: "onboarding.quickActions.runProjects".localized)
                chip(icon: "chart.bar.fill", text: "onboarding.quickActions.analyzeCode".localized)
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
    
    private func actionRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color)
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
    
    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.daSecondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.daEmerald.opacity(0.06))
        .clipShape(Capsule())
    }
}

#Preview {
    OnboardingQuickActionsView(onNext: {}, onPrevious: {})
}
