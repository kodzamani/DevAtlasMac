import SwiftUI

struct OnboardingAppearanceView: View {
    @Bindable var appViewModel: AppViewModel
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                themeCard(title: "onboarding.appearance.light".localized, isDark: false)
                themeCard(title: "onboarding.appearance.dark".localized, isDark: true)
            }

            HStack(spacing: 14) {
                Text("onboarding.appearance.accentColor".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.daSecondaryText)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(AppAccentColor.allCases) { accent in
                        accentDot(accent)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .daCardSurface(cornerRadius: 10)

            Label("onboarding.appearance.allSet".localized, systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.daTertiaryText)
        }
    }

    private func themeCard(title: String, isDark: Bool) -> some View {
        let isSelected = appViewModel.isDarkMode == isDark

        return Button {
            appViewModel.isDarkMode = isDark
        } label: {
            VStack(spacing: 10) {
                MiniWindowPreview(isDark: isDark)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.daPrimaryText : Color.daSecondaryText)
            }
            .padding(10)
            .daCardSurface()
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.daAccent, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accentDot(_ accent: AppAccentColor) -> some View {
        let isSelected = languageManager.accentColor == accent

        return Button {
            languageManager.setAccentColor(accent)
        } label: {
            Circle()
                .fill(accent.color)
                .frame(width: 16, height: 16)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(2)
                .overlay {
                    Circle().strokeBorder(isSelected ? accent.color : Color.clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accent.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A miniature of the app's window, drawn with fixed colors so both themes show side by side.
private struct MiniWindowPreview: View {
    let isDark: Bool

    private var surface: Color { isDark ? Color(hex: "1A1A1C") : Color(hex: "F5F5F7") }
    private var sidebar: Color { isDark ? Color(hex: "2A2A2C") : Color(hex: "E9E9EC") }
    private var line: Color { isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.14) }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(["FF5F57", "FEBC2E", "28C840"], id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 5, height: 5)
                    }
                }
                .padding(.bottom, 6)

                RoundedRectangle(cornerRadius: 2).fill(Color.daAccent).frame(height: 7)
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2).fill(line).frame(height: 5)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: 72)
            .background(sidebar)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(line).frame(width: 56, height: 6)

                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            FolderIconView(tint: Color.daAccent, size: 34, isInteractive: false)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface)
        }
        .frame(height: 124)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.daBorder, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingAppearanceView(appViewModel: AppViewModel())
        .environment(LanguageManager())
}
