import SwiftUI

struct PagesDeploymentLogsView: View {
    @Environment(PagesDeploymentLogsViewModel.self) private var pagesDeploymentLogsViewModel
    let projectName: String
    let deployment: PagesDeployment

    @State private var response: PagesDeploymentLogResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Deployment") {
                LabeledContent("ID", value: deployment.shortID ?? deployment.id)
                LabeledContent("Environment", value: deployment.environmentTitle)
                LabeledContent("Status", value: deployment.statusTitle)
                if let total = response?.total {
                    LabeledContent("Log Entries", value: total.formatted())
                }
            }

            Section("Logs") {
                if isLoading && response == nil {
                    ProgressView("Loading Logs")
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else if let entries = response?.data, entries.isEmpty == false {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                Text(entry.levelTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(logLevelColor(entry.level))

                                Spacer(minLength: 0)

                                if let timestamp = entry.timestamp {
                                    Text(timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(entry.displayMessage)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No deployment logs returned.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Deployment Logs")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: deployment.id) {
            await loadLogs()
        }
        .refreshable {
            await loadLogs()
        }
    }

    private func loadLogs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            response = try await pagesDeploymentLogsViewModel.loadPagesDeploymentLogs(
                projectName: projectName,
                deploymentID: deployment.id
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logLevelColor(_ level: String?) -> Color {
        switch level?.lowercased() {
        case "error", "fatal":
            .red
        case "warn", "warning":
            .orange
        case "debug":
            .blue
        default:
            .secondary
        }
    }
}
