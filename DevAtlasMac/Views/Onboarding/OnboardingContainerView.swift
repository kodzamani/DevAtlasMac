import SwiftUI

/// Two-pane setup assistant: a step rail on the left, the current page and its actions on the right.
struct OnboardingContainerView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(LanguageManager.self) private var languageManager
    @Bindable var viewModel: OnboardingViewModel

    @State private var languageTrigger: Int = 0

    var body: some View {
        ZStack {
            AuroraBackground()

            HStack(spacing: 0) {
                stepRail
                Divider()
                VStack(spacing: 0) {
                    pageArea
                    footer
                }
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(appViewModel.isDarkMode ? .dark : .light)
        // The palette is read from UserDefaults, so a theme or accent change needs a rebuild.
        .id(appViewModel.isDarkMode)
        .id(languageManager.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            languageTrigger += 1
        }
        .id(languageTrigger)
    }

    // MARK: - Step Rail

    private var stepRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image("logo_brand")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                Text("app.name".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
            }
            .padding(.bottom, 26)

            ForEach(OnboardingPage.allCases, id: \.self) { page in
                stepRow(page)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .frame(width: 236, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.daCard)
    }

    private func stepRow(_ page: OnboardingPage) -> some View {
        let isCurrent = page == viewModel.currentPage
        let isDone = page.rawValue < viewModel.currentPageIndex

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.go(to: page)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isCurrent || isDone ? Color.daAccent : Color.clear)
                        Circle()
                            .strokeBorder(isCurrent || isDone ? Color.daAccent : Color.daSeparator, lineWidth: 1)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(page.rawValue + 1)")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(isCurrent ? Color.white : Color.daTertiaryText)
                        }
                    }
                    .frame(width: 22, height: 22)

                    Text(page.stepTitle)
                        .font(.system(size: 12, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Color.daPrimaryText : Color.daTertiaryText)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isCurrent ? .isSelected : [])

            if page != OnboardingPage.allCases.last {
                Rectangle()
                    .fill(isDone ? Color.daAccent : Color.daBorder)
                    .frame(width: 1, height: 16)
                    .padding(.leading, 10.5)
            }
        }
    }

    // MARK: - Page

    private var pageArea: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let title = viewModel.currentPage.title {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("onboarding.stepCounter".localized(viewModel.currentPageIndex + 1, viewModel.totalPages))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.daAccent)

                            Text(title)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Color.daPrimaryText)

                            Text(viewModel.currentPage.subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.daTertiaryText)
                        }
                    }

                    pageContent
                }
                .frame(maxWidth: 840)
                .padding(.horizontal, 40)
                .padding(.top, 44)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.never)
        }
        .id(viewModel.currentPage)
        .transition(.opacity.combined(with: .offset(y: 8)))
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
        HStack(spacing: 10) {
            if viewModel.currentPage != .appearance {
                Button("onboarding.welcome.skip".localized) {
                    viewModel.skipOnboarding()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color.daTertiaryText)
            }

            Spacer()

            if viewModel.currentPage != .welcome {
                Button("common.back".localized) {
                    viewModel.previousPage()
                }
                .controlSize(.large)
                .keyboardShortcut("[", modifiers: .command)
            }

            Button(primaryTitle) {
                if viewModel.currentPage == .appearance {
                    viewModel.completeOnboarding()
                } else {
                    viewModel.nextPage()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.daAccent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
        .overlay(alignment: .top) { Divider() }
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
}
