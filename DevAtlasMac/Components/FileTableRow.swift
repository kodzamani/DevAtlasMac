import SwiftUI

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

    private var barColor: Color {
        if barWidthRatio > 0.75 { return Color(hex: "EF4444") }
        if barWidthRatio > 0.5 { return Color(hex: "F59E0B") }
        if barWidthRatio > 0.25 { return Color(hex: "3B82F6") }
        return Color(hex: "10B981")
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(index)")
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.relativePath)
                    .font(.daFont(size: 11, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(file.fileExtension)
                .font(.daFont(size: 10, weight: .medium))
                .foregroundStyle(Color.daTertiaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.daLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 80, alignment: .center)

            HStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.daLightGray)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor.opacity(0.7))
                            .frame(width: geometry.size.width * barWidthRatio, height: 4)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(width: 40)

                Text(formatNumber(file.lineCount))
                    .font(.daFont(size: 11, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
                    .frame(width: 50, alignment: .trailing)
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Color.daLightGray.opacity(0.5) : Color.clear)
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
        .background(Color.daWhite)
    }

    private static let lineCountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()

    private func formatNumber(_ n: Int) -> String {
        FileTableRow.lineCountFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
