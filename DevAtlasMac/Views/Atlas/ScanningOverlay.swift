import SwiftUI

struct ScanningOverlay: View {
    let progress: ScanProgress

    @State private var pulseOpacity: Double = 0.7

    var body: some View {
        ZStack {
            Color.daOffWhite.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                currentPathDisplay
                progressBar
                projectsFoundText
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 50)
            .frame(width: 360)
            .background(Color.daWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.daBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 20, y: 0)
        }
    }


    // MARK: - Current Path
    private var currentPathDisplay: some View {
        HStack(spacing: 10) {
            Text(progress.currentPath)
                .font(.daFileExtension)
                .foregroundStyle(Color.daTertiaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.daLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 20)
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.daBorder)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.daBlue)
                    .frame(width: max(0, geo.size.width * progress.progressPercentage / 100))
                    .opacity(pulseOpacity)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: pulseOpacity
                    )
            }
        }
        .frame(height: 8)
        .padding(.bottom, 20)
        .onAppear {
            pulseOpacity = 1.0
        }
    }

    // MARK: - Found Count
    private var projectsFoundText: some View {
        Text("scan.foundProjects".localized(progress.projectsFound))
            .font(.daBody)
            .foregroundStyle(Color.daTertiaryText)
    }
}
