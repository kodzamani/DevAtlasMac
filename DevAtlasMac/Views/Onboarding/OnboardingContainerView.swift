import SwiftUI

/// A centered setup assistant with horizontal progress and persistent navigation.
struct OnboardingContainerView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: OnboardingViewModel

    @State private var languageTrigger: Int = 0

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    OnboardingStepper(
                        currentPage: viewModel.currentPage,
                        selectPage: viewModel.go
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    Divider()

                    pageArea
                    footer
                }
                .frame(maxWidth: 1040, maxHeight: 740)
                .background(Color.daOffWhite.opacity(0.94), in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.daCardEdge, lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(appViewModel.isDarkMode ? 0.16 : 0.06), radius: 28, y: 12)

                Button("onboarding.welcome.skip".localized, action: viewModel.skipOnboarding)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.daTertiaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .opacity(viewModel.currentPage == .appearance ? 0 : 1)
                    .disabled(viewModel.currentPage == .appearance)
                    .accessibilityHidden(viewModel.currentPage == .appearance)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(appViewModel.isDarkMode ? .dark : .light)
        // Accent colors are read from UserDefaults, so changing the accent needs a rebuild.
        .id(languageManager.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            languageTrigger += 1
        }
        .id(languageTrigger)
        .transaction { transaction in
            if reduceMotion {
                transaction.disablesAnimations = true
            }
        }
    }

    // MARK: - Page

    private var pageArea: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    if let title = viewModel.currentPage.title {
                        VStack(spacing: 4) {
                            Text(title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color.daPrimaryText)
                                .accessibilityAddTraits(.isHeader)

                            Text(viewModel.currentPage.subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.daTertiaryText)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    }

                    pageContent
                }
                .frame(maxWidth: 820)
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.automatic)
        }
        .id(viewModel.currentPage)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
        .clipped()
    }

    @ViewBuilder
    private var pageContent: some View {
        switch viewModel.currentPage {
        case .welcome:
            OnboardingWelcomeView()
        case .languageSelection:
            OnboardingLanguageSelectionView()
        case .features:
            OnboardingFeaturesView()
        case .quickActions:
            OnboardingQuickActionsView()
        case .statsNotebook:
            OnboardingStatsNotebookView()
        case .appearance:
            OnboardingAppearanceView(appViewModel: appViewModel)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        ZStack {
            Text("onboarding.stepCounter".localized(viewModel.currentPageIndex + 1, viewModel.totalPages))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.daTertiaryText)

            HStack(spacing: 16) {
                backButton
                Spacer(minLength: 0)
                nextButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.daCard, in: UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var backButton: some View {
        Button(action: viewModel.previousPage) {
            Label("common.back".localized, systemImage: "arrow.left")
                .frame(minWidth: 72, minHeight: 24)
        }
        .controlSize(.large)
        .keyboardShortcut("[", modifiers: .command)
        .disabled(viewModel.currentPage == .welcome)
    }

    private var nextButton: some View {
        Button(action: advance) {
            HStack(spacing: 10) {
                Text(primaryTitle)
                Image(systemName: viewModel.currentPage == .appearance ? "checkmark" : "arrow.right")
                    .accessibilityHidden(true)
            }
            .font(.system(size: 13, weight: .semibold))
            .frame(minWidth: 140, minHeight: 24)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.daAccent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }

    private func advance() {
        if viewModel.currentPage == .appearance {
            viewModel.completeOnboarding()
        } else {
            viewModel.nextPage()
        }
    }

    private var primaryTitle: String {
        switch viewModel.currentPage {
        case .welcome: return "onboarding.welcome.getStarted".localized
        case .appearance: return "onboarding.appearance.start".localized
        default: return "common.next".localized
        }
    }
}

#Preview {
    OnboardingContainerView(viewModel: OnboardingViewModel())
        .environment(AppViewModel())
        .environment(LanguageManager())
        .frame(width: 1200, height: 800)
}
