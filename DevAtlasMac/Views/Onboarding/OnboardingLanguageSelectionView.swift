import SwiftUI

struct OnboardingLanguageSelectionView: View {
    @Environment(LanguageManager.self) private var languageManager
    let onNext: () -> Void
    let onPrevious: () -> Void
    
    @State private var selectedLanguage: AppLanguage = .english
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.daAccent)
                    .frame(width: 64, height: 64)
                    .background(Color.daAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text("settings.language".localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.daPrimaryText)
                
                Text("settings.language.select".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
            }
            
            Spacer().frame(height: 32)
            
            // Language Grid
            VStack(spacing: 12) {
                ForEach(Array(AppLanguage.allCases.chunked(into: 4)), id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row) { language in
                            languageButton(language)
                        }
                    }
                }
            }
            
            Spacer().frame(height: 28)
            
            // Selected Language Preview
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.daAccent)
                
                Text(selectedLanguage.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.daWhite)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            
            Spacer()
            
            // Buttons
            OnboardingButtons(
                primaryTitle: "common.next".localized,
                primaryAction: {
                    languageManager.setLanguage(selectedLanguage)
                    onNext()
                },
                secondaryTitle: "common.previous".localized,
                secondaryAction: onPrevious
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.daOffWhite)
        .onAppear {
            selectedLanguage = languageManager.selectedLanguage
        }
    }
    
    private func languageButton(_ language: AppLanguage) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedLanguage = language
                // Apply language immediately so all texts/buttons update in place
                languageManager.setLanguage(language)
            }
        } label: {
            VStack(spacing: 6) {
                Text(flagEmoji(for: language))
                    .font(.system(size: 28))
                
                Text(language.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selectedLanguage == language ? Color.daPrimaryText : Color.daSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedLanguage == language ? Color.daAccent.opacity(0.1) : Color.daWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedLanguage == language ? Color.daAccent : Color.daBorder.opacity(0.6), lineWidth: selectedLanguage == language ? 2 : 1)
            )
            .shadow(color: selectedLanguage == language ? Color.daAccent.opacity(0.15) : Color.black.opacity(0.04), radius: selectedLanguage == language ? 8 : 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func flagEmoji(for language: AppLanguage) -> String {
        switch language {
        case .english: return "🇺🇸"
        case .turkish: return "🇹🇷"
        case .german: return "🇩🇪"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        case .korean: return "🇰🇷"
        case .italian: return "🇮🇹"
        case .french: return "🇫🇷"
        }
    }
}

// Helper to chunk array
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    OnboardingLanguageSelectionView(onNext: {}, onPrevious: {})
        .environment(LanguageManager())
}
