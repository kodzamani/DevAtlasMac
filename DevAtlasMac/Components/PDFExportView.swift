import SwiftUI
import MarkdownUI

/// A view for rendering note content as PDF
struct PDFExportView: View {
    let noteContent: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Markdown(noteContent)
                .markdownTheme(.gitHub)
                .environment(\.dynamicTypeSize, .small)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color.white)
    }
}
