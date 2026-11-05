import SwiftUI

/// Slim, non-blocking scan indicator. Existing projects stay usable while a scan runs.
struct ScanStatusStrip: View {
    let progress: ScanProgress

    private var fraction: Double {
        min(max(progress.progressPercentage / 100, 0), 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.mini)

                Text("scan.scanning".localized)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.daSecondaryText)

                Text("scan.foundProjects".localized(progress.projectsFound))
                    .foregroundStyle(Color.daTertiaryText)
                    .fixedSize()

                Text(progress.currentPath)
                    .foregroundStyle(Color.daMutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(Color.daTertiaryText)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 12)
            .frame(height: 28)

            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.daAccent)
                    .frame(width: proxy.size.width * fraction)
                    .animation(.linear(duration: 0.2), value: fraction)
            }
            .frame(height: 2)
            .background(Color.daBorder)
        }
        .accessibilityElement(children: .combine)
    }
}
