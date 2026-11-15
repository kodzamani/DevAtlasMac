import SwiftUI

/// A neutral two-letter tile; the agents' own logos are not bundled.
struct AgentMonogram: View {
    let agent: CodingAgent
    var size: CGFloat = 24
    var dimmed = false

    private var letters: String {
        let words = agent.name.split(separator: " ")
        if words.count > 1 { return String(words.prefix(2).compactMap(\.first)) }
        return String(agent.name.prefix(2))
    }

    private var tint: Color {
        let palette: [Color] = [.orange, .blue, .purple, .teal, .green, .pink, .indigo, .mint, .brown, .cyan]
        let seed = agent.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[seed % palette.count]
    }

    var body: some View {
        Text(letters)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(dimmed ? Color.daMutedText : tint)
            .frame(width: size, height: size)
            .background((dimmed ? Color.primary : tint).opacity(dimmed ? 0.05 : 0.15),
                        in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}
