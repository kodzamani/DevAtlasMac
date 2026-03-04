import SwiftUI

struct NoteSettingsView: View {
    @Bindable var notebookVM: NotebookViewModel
    let note: NotebookNote
    @Environment(\.dismiss) private var dismiss
    
    @State private var colorCode: String
    @State private var iconName: String
    @State private var theme: String
    @State private var tagsText: String
    @State private var folderText: String

    let availableColors = ["default", "blue", "red", "green", "yellow", "orange", "purple"]
    let availableIcons = ["none", "doc.text", "star.fill", "bookmark.fill", "bolt.fill", "heart.fill", "flag.fill", "briefcase.fill"]
    let availableThemes = ["default", "dots", "lines"]
    
    init(notebookVM: NotebookViewModel, note: NotebookNote) {
        self.notebookVM = notebookVM
        self.note = note
        _colorCode = State(initialValue: note.colorCode ?? "default")
        _iconName = State(initialValue: note.iconName ?? "none")
        _theme = State(initialValue: note.theme ?? "default")
        _tagsText = State(initialValue: note.tags?.joined(separator: ", ") ?? "")
        _folderText = State(initialValue: note.folder ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("notebook.noteSettings".localized)
                .font(.daSectionTitle)
                .foregroundStyle(Color.daPrimaryText)
            
            Divider()
            
            // Icon
            VStack(alignment: .leading, spacing: 6) {
                Text("notebook.icon".localized)
                    .font(.daSmallLabelSemiBold)
                    .foregroundStyle(Color.daSecondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                if icon == "none" {
                                    Text("notebook.none".localized)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(iconName == icon ? Color.daWhite : Color.daSecondaryText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(iconName == icon ? Color.daBlue : Color.daLightGray)
                                        .clipShape(Capsule())
                                } else {
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(iconName == icon ? Color.daWhite : Color.daSecondaryText)
                                        .padding(8)
                                        .background(iconName == icon ? Color.daBlue : Color.daLightGray)
                                        .clipShape(Circle())
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Color
            VStack(alignment: .leading, spacing: 6) {
                Text("notebook.color".localized)
                    .font(.daSmallLabelSemiBold)
                    .foregroundStyle(Color.daSecondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableColors, id: \.self) { color in
                            Button {
                                colorCode = color
                            } label: {
                                Circle()
                                    .fill(colorForString(color))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(colorCode == color ? Color.daPrimaryText : Color.clear, lineWidth: 2)
                                    )
                                    .padding(2) // spacing for stroke
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Theme
            VStack(alignment: .leading, spacing: 6) {
                Text("notebook.theme".localized)
                    .font(.daSmallLabelSemiBold)
                    .foregroundStyle(Color.daSecondaryText)
                Picker("", selection: $theme) {
                    ForEach(availableThemes, id: \.self) { t in
                        Text(t.capitalized).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 6) {
                Text("notebook.tagsCommaSeparated".localized)
                    .font(.daSmallLabelSemiBold)
                    .foregroundStyle(Color.daSecondaryText)
                TextField("notebook.tagsPlaceholder".localized, text: $tagsText)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Folder
            VStack(alignment: .leading, spacing: 6) {
                Text("notebook.folder".localized)
                    .font(.daSmallLabelSemiBold)
                    .foregroundStyle(Color.daSecondaryText)
                TextField("notebook.folderPlaceholder".localized, text: $folderText)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("common.cancel".localized) {
                    dismiss()
                }
                Spacer()
                Button("common.save".localized) {
                    let parsedTags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    Task {
                        await notebookVM.updateNoteVisuals(
                            colorCode: colorCode,
                            iconName: iconName == "none" ? nil : iconName,
                            theme: theme,
                            folder: folderText.isEmpty ? nil : folderText,
                            tags: parsedTags.isEmpty ? nil : parsedTags,
                            for: note
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(20)
        .frame(width: 350, height: 480)
    }
    
    private func colorForString(_ color: String) -> Color {
        switch color {
        case "blue": return .daBlue
        case "red": return Color(hex: "EF4444")
        case "green": return .daGreen
        case "yellow": return Color(hex: "F59E0B")
        case "orange": return .daOrange
        case "purple": return Color(hex: "8B5CF6")
        default: return .daSecondaryText // "default" case
        }
    }
}
