import Foundation
import SwiftUI
import Observation

/// Onboarding ViewModel - manages onboarding state and navigation
@Observable
final class OnboardingViewModel {
    // MARK: - State
    var currentPage: OnboardingPage = .welcome
    var isPresented: Bool = false
    
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

