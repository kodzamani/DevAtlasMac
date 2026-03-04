import Foundation

// MARK: - Analyzer Error

enum AnalyzerError: Error {
    case peripheryNotFound
    case executionFailed(String)
    case parsingFailed
    case unsupportedLanguage(String)
}
