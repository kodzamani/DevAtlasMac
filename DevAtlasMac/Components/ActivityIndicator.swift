import SwiftUI

struct ActivityIndicator: View {
    let level: ActivityLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(level.localizedName)
                .font(.daSmallLabel)
                .foregroundStyle(color)
        }
    }
    
    private var color: Color {
        switch level {
        case .high: return .green
        case .medium: return .orange
        case .low: return .gray
        }
    }
}