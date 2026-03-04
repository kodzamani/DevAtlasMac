import SwiftUI

struct OnboardingStatsNotebookView: View {
    let onNext: () -> Void
    let onPrevious: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    iconBadge(icon: "chart.bar.fill", color: Color.daBlue)
                    iconBadge(icon: "note.text", color: Color.daEmerald)
                }
                
                Text("onboarding.statsNotebook.title".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.daPrimaryText)
                
                Text("onboarding.twoMoreFeatures".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Spacer().frame(height: 28)
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.daBlue)
                        Text("onboarding.features.feature2.title".localized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.daPrimaryText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        featureItem(icon: "chart.pie", text: "onboarding.stats.languageBreakdown".localized, color: Color.daBlue)
                        featureItem(icon: "doc.text", text: "onboarding.stats.lineCountAnalysis".localized, color: Color.daBlue)
                        featureItem(icon: "clock", text: "onboarding.stats.timeInsights".localized, color: Color.daBlue)
                        featureItem(icon: "square.and.arrow.up", text: "onboarding.stats.exportReports".localized, color: Color.daBlue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.daWhite)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.daBorder.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.daEmerald)
                        Text("onboarding.features.feature3.title".localized)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.daPrimaryText)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        featureItem(icon: "doc.richtext", text: "onboarding.notebook.projectDocs".localized, color: Color.daEmerald)
                        featureItem(icon: "tag", text: "onboarding.notebook.organizeTags".localized, color: Color.daEmerald)
                        featureItem(icon: "link", text: "onboarding.notebook.linkProjects".localized, color: Color.daEmerald)
                        featureItem(icon: "text.quote", text: "onboarding.notebook.markdownSupport".localized, color: Color.daEmerald)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.daWhite)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.daBorder.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            }
            
            Spacer()
            
            // Buttons
            OnboardingNavButtons(onNext: onNext, onPrevious: onPrevious)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.daOffWhite)
    }
    
    private func iconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 48, height: 48)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func featureItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.daSecondaryText)
        }
    }
}

#Preview {
    OnboardingStatsNotebookView(onNext: {}, onPrevious: {})
}
