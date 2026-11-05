import SwiftUI

struct OnboardingLanguageSelectionView: View {
    @Environment(LanguageManager.self) private var languageManager

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(AppLanguage.allCases) { language in
                languageButton(language)
            }
        }
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        let isSelected = languageManager.selectedLanguage == language

        return Button {
            // Applied immediately so every text on the page updates in place.
            languageManager.setLanguage(language)
        } label: {
            VStack(spacing: 8) {
                Text(flagEmoji(for: language))
                    .font(.system(size: 26))

                Text(language.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.daPrimaryText : Color.daSecondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .daCardSurface(cornerRadius: 10)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.daAccent.opacity(0.08))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.daAccent, lineWidth: 1.5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.daAccent)
                        .padding(7)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

#Preview {
    OnboardingLanguageSelectionView()
        .environment(LanguageManager())
}
