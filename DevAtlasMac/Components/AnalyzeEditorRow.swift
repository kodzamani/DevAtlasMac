import SwiftUI
import AppKit

struct AnalyzeEditorRow: View {
    let editor: CodeEditor
    let icon: NSImage
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(editor.name)
                    .font(.daBody)
                    .foregroundStyle(Color.daPrimaryText)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isHovered ? Color.daLightGray : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
