import Foundation

// MARK: - Localization Helper
extension String {
    var localized: String {
        let language = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.english.rawValue
        
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        
        return String(localized: String.LocalizationValue(self))
    }
    
    func localized(_ arguments: CVarArg...) -> String {
        let format = self.localized
        return String(format: format, arguments: arguments)
    }
}
