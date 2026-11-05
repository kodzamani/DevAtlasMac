import SwiftUI

/// Shared with the header row in `ProjectAnalyzeView`, so the columns line up.
enum FileTableColumn {
    static let index: CGFloat = 34
    static let fileExtension: CGFloat = 72
    static let lines: CGFloat = 110
}

struct FileTableRow: View {
    let index: Int
    let file: FileLineInfo
    let maxLineCount: Int
    let projectPath: String
    let runner: ProjectRunner

    @State private var isHovered = false
    @State private var showEditorPicker = false

    private var barWidthRatio: CGFloat {
        guard maxLineCount > 0 else { return 0 }
        return CGFloat(file.lineCount) / CGFloat(maxLineCount)
    }

    private var fileName: String {
        (file.relativePath as NSString).lastPathComponent
    }

    private var directory: String {
        (file.relativePath as NSString).deletingLastPathComponent
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(index)")
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(Color.daMutedText)
                .frame(width: FileTableColumn.index, alignment: .center)

            HStack(spacing: 8) {
                Text(fileName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.daPrimaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)

                if !directory.isEmpty {
                    Text(directory)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.daTertiaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if isHovered {
                    Button {
                        showEditorPicker = true
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.daTertiaryText)
                    }
                    .buttonStyle(.plain)
                    .help("common.openWith".localized)
                    .accessibilityLabel("common.openWith".localized)
                }
            }
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(file.relativePath)

            Text(file.fileExtension)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.daTertiaryText)
                .lineLimit(1)
                .frame(width: FileTableColumn.fileExtension, alignment: .leading)

            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 44, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.daAccent.opacity(0.75))
                            .frame(width: max(2, 44 * barWidthRatio), height: 4)
                    }
                    .accessibilityHidden(true)

                Text(file.lineCount.formatted())
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.daPrimaryText)
                    .lineLimit(1)
                    .frame(width: 50, alignment: .trailing)
            }
            .frame(width: FileTableColumn.lines, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Color.primary.opacity(isHovered ? 0.035 : 0))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) {
            showEditorPicker = true
        }
        .popover(isPresented: $showEditorPicker, arrowEdge: .bottom) {
            editorPickerPopover
        }
    }

    private var editorPickerPopover: some View {
        let editors = runner.installedEditors()
        let filePath = (projectPath as NSString).appendingPathComponent(file.relativePath)
        return VStack(alignment: .leading, spacing: 0) {
            Text("common.openWith".localized)
                .font(.daBodySemiBold)
                .foregroundStyle(Color.daPrimaryText)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            if editors.isEmpty {
                Text("projects.noEditorsFound".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                    .padding(14)
            } else {
                VStack(spacing: 0) {
                    ForEach(editors) { editor in
                        AnalyzeEditorRow(
                            editor: editor,
                            icon: runner.editorIcon(for: editor)
                        ) {
                            runner.openInEditor(editor, at: filePath)
                            showEditorPicker = false
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 200)
        .background(Color.daCard)
    }
}
