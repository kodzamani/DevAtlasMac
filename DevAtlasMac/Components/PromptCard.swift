import SwiftUI
import AppKit

/// A card view that displays an AI prompt with copy functionality
struct PromptCard: View {
    let title: String
    let description: String
    let prompt: String
    
    @State private var copied = false
    @State private var isExpanded = false
    
    private var wordCount: Int {
        prompt.split(separator: " ").count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                // Word count badge
                Text("aiprompts.wordCount".localized(wordCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )
                
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "aiprompts.copied".localized : "aiprompts.copy".localized)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(copied ? .green : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(copied ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Prompt preview / full view
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button {
                    isExpanded = true
                } label: {
                    HStack(spacing: 4) {
                        Text("aiprompts.expand".localized)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $isExpanded) {
            PromptDetailView(
                title: title,
                description: description,
                prompt: prompt,
                wordCount: wordCount,
                isPresented: $isExpanded
            )
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copied = false
            }
        }
    }
}
