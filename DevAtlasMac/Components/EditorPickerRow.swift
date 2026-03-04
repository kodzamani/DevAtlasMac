import SwiftUI
import AppKit

struct EditorPickerRow: View {
    let editor: CodeEditor
    let icon: NSImage
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(editor.name)
                    .font(.daBody)
                    .foregroundStyle(Color.daPrimaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.daLightGray : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
