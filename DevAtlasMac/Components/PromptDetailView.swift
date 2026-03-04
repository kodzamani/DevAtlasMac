import SwiftUI
import AppKit

/// A detailed view for viewing and copying a full AI prompt
struct PromptDetailView: View {
    let title: String
    let description: String
    let prompt: String
    let wordCount: Int
    @Binding var isPresented: Bool
    
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
            
            ScrollView {
                Text(prompt)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
            
            HStack {
                Text("aiprompts.wordCount".localized(wordCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "aiprompts.copied".localized : "aiprompts.copy".localized)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(copied ? Color.green : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(minWidth: 700, idealWidth: 800, minHeight: 400, idealHeight: 600)
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
