import SwiftUI
import AppKit

struct DockerLogsSheet: View {
    let container: DockerContainer
    @Environment(\.dismiss) private var dismiss
    @State private var output = ""
    @State private var query = ""
    @State private var error: String?
    @State private var isLoading = false

    private var lines: [String] {
        let all = output.components(separatedBy: "\n")
        return query.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(query) }
    }
    private var filtered: String { lines.joined(separator: "\n") }
    private var lineCount: Int { output.isEmpty ? 0 : lines.filter { !$0.isEmpty }.count }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)
            toolbar.padding(.horizontal, 18).padding(.bottom, 12)
            if let error {
                DockerBanner(kind: .warning, tint: .red, text: error).padding(.horizontal, 18).padding(.bottom, 12)
            }
            Divider().opacity(0.6)
            ScrollView([.horizontal, .vertical]) {
                Text(filtered.isEmpty ? "docker.logs.empty".localized : filtered)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(filtered.isEmpty ? Color.daTertiaryText : Color.daPrimaryText)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
            }
            .background(Color.primary.opacity(0.03))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().opacity(0.6)
            HStack(spacing: 6) {
                DockerIcon(.clock, size: 10)
                Text("docker.logs.detail".localized)
                Spacer()
            }
            .font(.system(size: 10.5)).foregroundStyle(.tertiary)
            .padding(.horizontal, 18).frame(height: 28)
        }
        .frame(minWidth: 720, idealWidth: 860, minHeight: 480, idealHeight: 600)
        .task { await refresh() }
    }

    private var header: some View {
        HStack(spacing: 11) {
            DockerIconTile(kind: .logs, tint: .daDocker, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(container.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    DockerStatusDot(color: container.stateColor, isLive: container.isRunning, size: 6)
                    Text(container.stateTitle).foregroundStyle(container.stateColor)
                    Text("·").foregroundStyle(.tertiary)
                    Text(container.image).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                .font(.system(size: 11, weight: .medium))
            }
            Spacer(minLength: 8)
            DockerIconButton(kind: .xmark, help: "docker.close".localized, size: 26) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                DockerIcon(.search, size: 12).foregroundStyle(.tertiary)
                TextField("docker.logs.search".localized, text: $query)
                    .textFieldStyle(.plain).font(.system(size: 12))
                if !query.isEmpty {
                    Button { query = "" } label: { DockerIcon(.xmark, size: 10).foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9).frame(height: 28)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))

            DockerChip(kind: .logs, text: "docker.logs.lines".localized(lineCount), tint: .secondary)
            if isLoading { ProgressView().controlSize(.small) }
            DockerIconButton(kind: .refresh, help: "docker.refresh".localized, size: 28) { Task { await refresh() } }
                .disabled(isLoading)
            DockerIconButton(kind: .copy, help: "docker.copy".localized, size: 28) {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(filtered, forType: .string)
            }
            .disabled(output.isEmpty)
        }
    }

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let result = await Task.detached { Result { try DockerService.logs(containerID: container.id) } }.value
        switch result {
        case .success(let text): output = text; error = nil
        case .failure(let failure): error = failure.localizedDescription
        }
    }
}
