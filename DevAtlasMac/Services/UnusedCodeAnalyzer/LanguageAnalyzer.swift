import Foundation

// MARK: - Language Analyzer Protocol

protocol LanguageAnalyzer {
    var languageName: String { get }
    func analyze(projectPath: String) throws -> [UnusedCodeResult]
}
