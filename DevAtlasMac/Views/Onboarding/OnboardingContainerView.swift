import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Bindable var viewModel: OnboardingViewModel
    private let contentMaxWidth: CGFloat = 580
    
    @State private var dragOffset: CGFloat = 0
    @State private var languageTrigger: Int = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.daOffWhite
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Dots
                progressDots
              
                ZStack {
                    switch viewModel.currentPage {
                    case .welcome:
                        OnboardingWelcomeView(
                            onNext: { viewModel.nextPage() },
                            onSkip: { viewModel.skipOnboarding() }
                        )
                        
                    case .languageSelection:
                        OnboardingLanguageSelectionView(
                            onNext: { viewModel.nextPage() },
                            onPrevious: { viewModel.previousPage() }
                        )
                        
                    case .features:
                        OnboardingFeaturesView(
                            onNext: { viewModel.nextPage() },
                            onPrevious: { viewModel.previousPage() }
                        )
                        
                    case .quickActions:
                        OnboardingQuickActionsView(
                            onNext: { viewModel.nextPage() },
                            onPrevious: { viewModel.previousPage() }
                        )
                        
                    case .statsNotebook:
                        OnboardingStatsNotebookView(
                            onNext: { viewModel.nextPage() },
                            onPrevious: { viewModel.previousPage() }
                        )
                        
                    case .appearance:
                        OnboardingAppearanceView(
                            appViewModel: appViewModel,
                            onComplete: { viewModel.completeOnboarding() },
                            onPrevious: { viewModel.previousPage() }
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: dragOffset > 0 ? .leading : .trailing).combined(with: .opacity),
                    removal: .move(edge: dragOffset > 0 ? .trailing : .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.35), value: viewModel.currentPage)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow horizontal drag
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 80
                            if value.translation.width > threshold {
                                // Swipe right - go to previous
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.previousPage()
                                }
                            } else if value.translation.width < -threshold {
                                // Swipe left - go to next
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.nextPage()
                                }
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                )
                
            }
            .frame(maxWidth: contentMaxWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(appViewModel.isDarkMode ? .dark : .light)
        .id(appViewModel.isDarkMode)
        // Force re-render onboarding content when app language changes
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            languageTrigger += 1
        }
        .id(languageTrigger)
    }
    
    // MARK: - Progress Dots
    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.totalPages, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentPageIndex ? Color.daBlue : Color.daBorder)
                    .frame(width: 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.currentPageIndex)
            }
        }
        .padding(.top, 20)
    }

}

#Preview {
    OnboardingContainerView(viewModel: OnboardingViewModel())
        .environment(AppViewModel())
}
