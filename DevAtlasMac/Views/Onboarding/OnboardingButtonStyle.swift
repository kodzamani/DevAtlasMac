import SwiftUI

struct OnboardingButtons: View {
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondaryAction: () -> Void
    var primaryIcon: String? = nil
    var primaryGradient: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: secondaryAction) {
                Text(secondaryTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.daSecondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.daWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.daBorder.opacity(0.7), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button(action: primaryAction) {
                HStack(spacing: 6) {
                    Text(primaryTitle)
                    if let icon = primaryIcon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    Group {
                        if primaryGradient {
                            LinearGradient(
                                colors: [Color.daBlue, Color.daEmerald],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.daBlue
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}

