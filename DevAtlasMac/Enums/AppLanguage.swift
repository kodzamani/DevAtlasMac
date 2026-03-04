import Foundation

/// Supported languages in the app
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case turkish = "tr"
    case german = "de"
    case japanese = "ja"
    case chinese = "zh-Hans"
    case korean = "ko"
    case italian = "it"
    case french = "fr"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "language.en".localized
        case .turkish: return "language.tr".localized
        case .german: return "language.de".localized
        case .japanese: return "language.ja".localized
        case .chinese: return "language.zh".localized
        case .korean: return "language.ko".localized
        case .italian: return "language.it".localized
        case .french: return "language.fr".localized
        }
    }
    
}
