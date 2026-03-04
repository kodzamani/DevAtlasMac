import Foundation

struct LanguageBreakdown: Identifiable {
    let id = UUID()
    let language: String
    let percentage: Double
    let color: String
}
