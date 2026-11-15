import SwiftUI

struct AgentPromptSuggestions: View {
    let onSelect: (AIPromptTemplate) -> Void
    let onBrowse: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("agents.prompts.title".localized, systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.daSecondaryText)

                Spacer(minLength: 8)

                Button(action: onBrowse) {
                    HStack(spacing: 4) {
                        Text("agents.prompts.browse".localized)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.daTertiaryText)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AIPromptLibrary.suggestions) { template in
                    AgentPromptSuggestionCard(template: template) { onSelect(template) }
                }
            }
        }
    }
}

private struct AgentPromptSuggestionCard: View {
    let template: AIPromptTemplate
    let action: () -> Void

    @State private var isHovered = false

    private var symbol: String {
        switch template.id {
        case "projectReport": "doc.text.magnifyingglass"
        case "unusedCode": "scissors"
        case "securityAudit": "checkmark.shield"
        case "bottleneck": "gauge.with.dots.needle.50percent"
        case "testGenerator": "testtube.2"
        default: "text.document"
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ChatMetrics.cardCorner, style: .continuous)

        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(isHovered ? Color.daAccent : Color.daSecondaryText)
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.daPrimaryText)
                        .lineLimit(1)

                    Text(template.description)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.daTertiaryText)
                        .lineLimit(2, reservesSpace: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.down.left")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.daAccent)
                    .opacity(isHovered ? 1 : 0)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .chatSurface(cornerRadius: ChatMetrics.cardCorner)
            .overlay(shape.strokeBorder(Color.daAccent.opacity(isHovered ? 0.4 : 0), lineWidth: 1))
            .background(shape.fill(Color.primary.opacity(isHovered ? 0.03 : 0)))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .accessibilityLabel(template.title)
        .accessibilityHint("agents.prompts.useHint".localized)
        .help("agents.prompts.useHint".localized)
    }
}
