import SwiftUI
import MarkdownUI

struct CustomMarkdownView: View {
    let content: String
    
    var body: some View {
        MarkdownUI.Markdown(content)
            .markdownTheme(.basic)
            .font(.system(size: 13))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
    }
}

