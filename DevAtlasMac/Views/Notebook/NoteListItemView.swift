import SwiftUI

struct NoteListItemView: View {
    let note: NotebookNote
    let isSelected: Bool
    var showProjectTag: Bool = false
    let onTap: () -> Void
    let onDelete: () -> Void
    var onClone: (() -> Void)? = nil
    var onTogglePin: (() -> Void)? = nil
    var onToggleArchive: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if note.isPinned == true {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.daOrange)
                    }
                    if let iconName = note.iconName, iconName != "none" {
                        Image(systemName: iconName)
                            .font(.system(size: 11))
                            .foregroundStyle(iconColor)
                    }
                    Text(note.title)
                        .font(.daBodySemiBold)
                        .foregroundStyle(Color.daPrimaryText)
                        .lineLimit(1)
                        .strikethrough(note.isArchived == true, color: .gray)
                    Spacer()
                    Text(formattedDate(note.updatedAt))
                        .font(.daSmallLabel)
                        .foregroundStyle(Color.daMutedText)
                }

                if !note.content.isEmpty {
                    Text(note.content.prefix(80).replacingOccurrences(of: "\n", with: " "))
                        .font(.daBody)
                        .foregroundStyle(Color.daTertiaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    if showProjectTag {
                        Text(note.projectName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.daAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.daAccentLight)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if !note.todos.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.daMutedText)
                            let done = note.todos.filter(\.isCompleted).count
                            Text("\(done)/\(note.todos.count)")
                                .font(.daSmallLabel)
                                .foregroundStyle(done == note.todos.count ? Color.daGreen : Color.daMutedText)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? selectionBackgroundColor : Color.daWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? selectionBorderColor : Color.daBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let pin = onTogglePin {
                Button { pin() } label: {
                    Label(
                        note.isPinned == true ? "notebook.unpinNote".localized : "notebook.pinNote".localized,
                        systemImage: note.isPinned == true ? "pin.slash" : "pin"
                    )
                }
            }
            if let clone = onClone {
                Button { clone() } label: {
                    Label("notebook.duplicateNote".localized, systemImage: "doc.on.doc")
                }
            }
            if let archive = onToggleArchive {
                Button { archive() } label: {
                    Label(
                        note.isArchived == true ? "notebook.unarchiveNote".localized : "notebook.archiveNote".localized,
                        systemImage: "archivebox"
                    )
                }
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("notebook.deleteNote".localized, systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helper Properties
    private var iconColor: Color {
        guard let customColor = note.colorCode, customColor != "default" else { return Color.daAccent }
        switch customColor {
        case "blue": return Color.daAccent
        case "red": return Color(hex: "EF4444")
        case "green": return Color.daGreen
        case "yellow": return Color(hex: "F59E0B")
        case "orange": return Color.daOrange
        case "purple": return Color(hex: "8B5CF6")
        default: return Color.daAccent
        }
    }
    
    private var selectionBackgroundColor: Color {
        guard let customColor = note.colorCode else { return Color.daAccentLight }
        switch customColor {
        case "blue": return Color.daAccentLight
        case "red": return Color(hex: "EF4444").opacity(0.1)
        case "green": return Color.daGreen.opacity(0.1)
        case "yellow": return Color(hex: "F59E0B").opacity(0.1)
        case "orange": return Color.daOrange.opacity(0.1)
        case "purple": return Color(hex: "8B5CF6").opacity(0.1)
        default: return Color.daAccentLight
        }
    }
    
    private var selectionBorderColor: Color {
        guard let customColor = note.colorCode else { return Color.daAccent.opacity(0.3) }
        switch customColor {
        case "blue": return Color.daAccent.opacity(0.3)
        case "red": return Color(hex: "EF4444").opacity(0.3)
        case "green": return Color.daGreen.opacity(0.3)
        case "yellow": return Color(hex: "F59E0B").opacity(0.3)
        case "orange": return Color.daOrange.opacity(0.3)
        case "purple": return Color(hex: "8B5CF6").opacity(0.3)
        default: return Color.daAccent.opacity(0.3)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
