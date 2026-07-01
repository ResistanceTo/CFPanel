import SwiftUI

struct WorkerRuntimeReleasesView: View {
    @Environment(WorkerReleasesViewModel.self) private var workerReleasesViewModel
    let runtime: WorkerRuntimeSummary

    @State private var snapshot: WorkerReleaseSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedVersion: WorkerVersion?

    var body: some View {
        List {
            contextSection
            operationalNotesSection
            statusSection
            deploymentsSection
            versionsSection
        }
        .navigationTitle("Deployments")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: runtime.id) {
            await loadSnapshot()
        }
        .refreshable {
            await loadSnapshot()
        }
        .sheet(item: $selectedVersion) { version in
            NavigationStack {
                WorkerVersionDetailView(scriptName: runtime.script.id, version: version)
            }
        }
    }

    private var contextSection: some View {
        Section("Script") {
            LabeledContent("Script", value: runtime.script.id)
            Text("This page only loads deployment and version history for the current script.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var operationalNotesSection: some View {
        if let snapshot, snapshot.operationalNotes.isEmpty == false {
            Section("Operational Notes") {
                ForEach(snapshot.operationalNotes) { note in
                    WorkerOperationalNoteRow(note: note)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let errorMessage {
            Section("Status") {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deploymentsSection: some View {
        Section("Deployments") {
            if let snapshot, snapshot.resolvedDeployments.isEmpty == false {
                ForEach(snapshot.resolvedDeployments) { deployment in
                    WorkerDeploymentRow(deployment: deployment)
                }
            } else if isLoading {
                ProgressView("Loading Deployments")
            } else {
                Text("No deployment history available.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var versionsSection: some View {
        Section("Versions") {
            if let snapshot, snapshot.resolvedVersions.isEmpty == false {
                ForEach(snapshot.resolvedVersions) { version in
                    Button {
                        selectedVersion = version
                    } label: {
                        WorkerVersionSummaryRow(
                            version: version,
                            deployment: snapshot.resolvedDeployments.first(where: { deployment in
                                deployment.versions.contains { $0.versionID == version.id }
                            })
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else if isLoading {
                ProgressView("Loading Versions")
            } else {
                Text("No version history returned.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadSnapshot() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await workerReleasesViewModel.loadWorkerReleaseSnapshot(scriptName: runtime.script.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
