import Foundation

struct CodeAnalysisResult {
    let files: [FileLineInfo]
    let totalLines: Int
    let totalFiles: Int
    let languageBreakdown: [LanguageBreakdown]
}
