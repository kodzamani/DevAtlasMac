import SwiftUI

/// Navigation buttons for onboarding flow (back/next)
struct OnboardingNavButtons: View {
    let onNext: () -> Void
    let onPrevious: () -> Void

    var body: some View {
        OnboardingButtons(
            primaryTitle: "common.next".localized,
            primaryAction: onNext,
            secondaryTitle: "common.back".localized,
            secondaryAction: onPrevious,
            primaryIcon: "arrow.right"
        )
    }
}
