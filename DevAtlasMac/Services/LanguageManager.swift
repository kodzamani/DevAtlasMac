import Foundation
import SwiftUI
import Observation

/// Language and Appearance Manager - manages app language and accent color
@Observable
final class LanguageManager {
    // MARK: - Storage Keys
    private let languageKey = "appLanguage"
    private let accentColorKey = "appAccentColor"
    private let themeModeKey = "appThemeMode"
    private let excludedPathsKey = "excludedPaths"
    
    // MARK: - Force Update Key (for triggering view refresh)
    private let forceUpdateKey = "forceUpdateCounter"
    
    
    // MARK: - State
    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: languageKey)
            updateLocale()
        }
    }
    
    var accentColor: AppAccentColor {
        didSet {
            UserDefaults.standard.set(accentColor.rawValue, forKey: accentColorKey)
        }
    }
    
    var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: themeModeKey)
        }
    }
    
    // MARK: - Excluded Paths
    var excludedPaths: [String] {
        didSet {
            let normalized = excludedPaths.map {
                URL(fileURLWithPath: $0)
                    .resolvingSymlinksInPath()
                    .standardizedFileURL
                    .path
            }
            UserDefaults.standard.set(normalized, forKey: excludedPathsKey)
        }
    }
    
    // MARK: - Initialization
    init() {
        // Load saved language or default to English
        let savedLanguage = UserDefaults.standard.string(forKey: languageKey) ?? AppLanguage.english.rawValue
        self.selectedLanguage = AppLanguage(rawValue: savedLanguage) ?? .english
        
        // Load saved accent color or default to blue
        let savedAccent = UserDefaults.standard.string(forKey: accentColorKey) ?? AppAccentColor.blue.rawValue
        self.accentColor = AppAccentColor(rawValue: savedAccent) ?? .blue
        
        // Load saved theme mode or default to system
        let savedTheme = UserDefaults.standard.string(forKey: themeModeKey) ?? ThemeMode.system.rawValue
        self.themeMode = ThemeMode(rawValue: savedTheme) ?? .system
        
        // Load saved excluded paths or default to empty
        let savedExcluded = UserDefaults.standard.stringArray(forKey: excludedPathsKey) ?? []
        self.excludedPaths = savedExcluded.map {
            URL(fileURLWithPath: $0)
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path
        }
        
        // Apply the loaded language
        self.updateLocale()
    }
    
    // MARK: - Methods
    private func updateLocale() {
        // Note: Locale.current cannot be changed globally in Swift
        // The app will use the selected language for localization through String(localized:)
    }
    
    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        // Force update trigger
        let current = UserDefaults.standard.integer(forKey: forceUpdateKey)
        UserDefaults.standard.set(current + 1, forKey: forceUpdateKey)
        // Post notification
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    func setAccentColor(_ color: AppAccentColor) {
        accentColor = color
        // Post notification
        NotificationCenter.default.post(name: .accentColorDidChange, object: nil)
    }
    
    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
    }
}
