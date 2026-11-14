import Foundation

// MARK: - Analyzer Error

enum AnalyzerError: Error {
    case executionFailed(String)
    case parsingFailed
    case unsupportedLanguage(String)
}
