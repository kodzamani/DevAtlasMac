import Foundation

/// Onboarding page types
enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case languageSelection = 1
    case features = 2
    case quickActions = 3
    case statsNotebook = 4
    case appearance = 5
}

extension OnboardingPage {
    /// The label of this page in the horizontal stepper.
    var stepTitle: String {
        switch self {
        case .welcome: return "onboarding.step.welcome".localized
        case .languageSelection: return "settings.language".localized
        case .features: return "onboarding.features.title".localized
        case .quickActions: return "onboarding.quickActions.title".localized
        case .statsNotebook: return "onboarding.statsNotebook.title".localized
        case .appearance: return "onboarding.appearance.title".localized
        }
    }

    /// The page heading. The welcome page has its own hero instead.
    var title: String? {
        self == .welcome ? nil : stepTitle
    }

    var subtitle: String {
        switch self {
        case .welcome: return ""
        case .languageSelection: return "settings.language.select".localized
        case .features: return "onboarding.discoverProjects".localized
        case .quickActions: return "onboarding.lightningAccess".localized
        case .statsNotebook: return "onboarding.twoMoreFeatures".localized
        case .appearance: return "onboarding.appearance.subtitle".localized
        }
    }
}
