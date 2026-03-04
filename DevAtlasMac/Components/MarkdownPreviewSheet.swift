import SwiftUI
import AppKit

/// A sheet view that displays the results of code analysis in an HTML format
struct MarkdownPreviewSheet: View {
    let htmlContent: String
    let results: [UnusedCodeResult]
    let projectPath: String
    let onCancel: () -> Void
    
    @State private var didCopyPrompt = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("analyze.analysisResults".localized)
                    .font(.daSectionTitle)
                    .foregroundStyle(Color.daPrimaryText)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.daMutedText)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.daOffWhite)
            
            Divider()
            
            // Content
            HTMLWebView(htmlContent: htmlContent)
                .background(Color.daWhite)
            
            Divider()
            
            // Footer Action
            HStack {
                Spacer()
                
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Text("analyze.cancel".localized)
                            .font(.daSmallLabelSemiBold)
                            .foregroundStyle(Color.daSecondaryText)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .frame(height: 27)
                    .background(Color.daLightGray)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Button(action: copyCleanupPrompt) {
                    HStack(spacing: 6) {
                        Image(systemName: didCopyPrompt ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(didCopyPrompt ? "analyze.copied".localized : "analyze.copyCleanupPrompt".localized)
                            .font(.daSmallLabelSemiBold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .frame(height: 27)
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.daOffWhite)
        }
        .frame(width: 1200, height: 800)
    }
    
    private func copyCleanupPrompt() {
        let prompt = UnusedCodeAnalyzer().generateRemovalPrompt(from: results, projectPath: projectPath)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prompt, forType: .string)
        
        didCopyPrompt = true
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didCopyPrompt = false
        }
    }
}
