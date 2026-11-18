import Foundation
import SwiftUI
import Combine

/// Onboarding ViewModel - manages onboarding state and navigation
final class OnboardingViewModel: ObservableObject {
    // MARK: - State
    @Published var currentPage: OnboardingPage = .welcome
    @Published var isPresented: Bool = false
    
    // MARK: - UserDefaults Keys
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    
    // MARK: - Computed Properties
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey) }
    }
    
    var currentPageIndex: Int {
        currentPage.rawValue
    }
    
    var totalPages: Int {
        OnboardingPage.allCases.count
    }
    
    // MARK: - Initialization
    init() {
        // Check if onboarding should be shown
        isPresented = !hasCompletedOnboarding
    }
    
    // MARK: - Navigation
    func nextPage() {
        if let next = OnboardingPage(rawValue: currentPage.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = next
            }
        }
    }
    
    func go(to page: OnboardingPage) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = page
        }
    }

    func previousPage() {
        if let prev = OnboardingPage(rawValue: currentPage.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = prev
            }
        }
    }
    
    // MARK: - Completion
    func completeOnboarding() {
        hasCompletedOnboarding = true
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
    // MARK: - Show Onboarding (for settings)
    func showOnboarding() {
        currentPage = .welcome
        isPresented = true
    }
}

