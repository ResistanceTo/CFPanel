import SwiftUI

struct PagesProjectDeploymentsView: View {
    @Environment(PagesDeploymentsViewModel.self) private var pagesDeploymentsViewModel
    let project: PagesProject

    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false
    @State private var productionDeployments: [PagesDeployment] = []
    @State private var previewDeployments: [PagesDeployment] = []
    @State private var isLoading = false
    @State private var isPerformingAction = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var selectedDeploymentForLogs: PagesDeployment?
    @State private var deploymentPendingDeletion: PagesDeployment?
    @State private var deploymentPendingRollback: PagesDeployment?

    private var productionSummary: PagesEnvironmentSummary {
        PagesEnvironmentSummary(title: "Production", deployments: productionDeployments)
    }

    private var previewSummary: PagesEnvironmentSummary {
        PagesEnvironmentSummary(title: "Preview", deployments: previewDeployments)
    }

    private var allOperationalNotes: [PagesOperationalNote] {
        var notes = productionSummary.operationalNotes
        for note in previewSummary.operationalNotes where notes.contains(note) == false {
            notes.append(note)
        }
        return notes
    }

    var body: some View {
        List {
            contextSection
            environmentStatusSection
            operationalNotesSection
            statusSection
            loadingOrErrorSection
            deploymentSection(title: "Production Deployments", deployments: productionDeployments)
            deploymentSection(title: "Preview Deployments", deployments: previewDeployments)
        }
        .navigationTitle("Deployments")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: project.id) {
            await loadDeployments()
        }
        .refreshable {
            await loadDeployments()
        }
        .sheet(item: $selectedDeploymentForLogs) { deployment in
            NavigationStack {
                PagesDeploymentLogsView(projectName: project.name, deployment: deployment)
            }
        }
        .countdownConfirmationDialog(
            "Delete this deployment?",
            isPresented: Binding(
                get: { deploymentPendingDeletion != nil },
                set: { newValue in
                    if newValue == false {
                        deploymentPendingDeletion = nil
                    }
                }
            ),
            message: deploymentDeletionMessage,
            actionTitle: "Delete Deployment",
            onCancel: {
                deploymentPendingDeletion = nil
            }
        ) {
            guard let deploymentPendingDeletion else { return }
            Task {
                await deleteDeployment(deploymentPendingDeletion)
                self.deploymentPendingDeletion = nil
            }
        }
        .countdownConfirmationDialog(
            "Rollback to this deployment?",
            isPresented: Binding(
                get: { deploymentPendingRollback != nil },
                set: { newValue in
                    if newValue == false {
                        deploymentPendingRollback = nil
                    }
                }
            ),
            message: rollbackConfirmationMessage,
            actionTitle: "Rollback Deployment",
            role: .destructive,
            onCancel: {
                deploymentPendingRollback = nil
            }
        ) {
            guard let deploymentPendingRollback else { return }
            Task {
                await rollbackDeployment(deploymentPendingRollback)
                self.deploymentPendingRollback = nil
            }
        }
    }

    private var contextSection: some View {
        Section("Project") {
            LabeledContent("Name", value: project.name)
            if let productionBranch = project.productionBranch {
                LabeledContent("Production Branch", value: productionBranch)
            }
            Text("Deployment history loads here on demand so the project directory page does not prefetch build history.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var environmentStatusSection: some View {
        Section("Environment Status") {
            PagesEnvironmentSummaryRow(summary: productionSummary)
            PagesEnvironmentSummaryRow(summary: previewSummary)
        }
    }

    @ViewBuilder
    private var operationalNotesSection: some View {
        if isLoading == false, allOperationalNotes.isEmpty == false {
            Section("Operational Notes") {
                ForEach(allOperationalNotes) { note in
                    PagesOperationalNoteRow(note: note)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage {
            Section("Status") {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var loadingOrErrorSection: some View {
        if isLoading && productionDeployments.isEmpty && previewDeployments.isEmpty {
            Section("Deployments") {
                ProgressView("Loading Deployments")
            }
        } else if let errorMessage {
            Section("Deployments") {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }
        } else if productionDeployments.isEmpty && previewDeployments.isEmpty {
            Section("Deployments") {
                Text("No deployment history available.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func deploymentSection(title: LocalizedStringResource, deployments: [PagesDeployment]) -> some View {
        if deployments.isEmpty == false {
            Section(title) {
                ForEach(deployments, id: \.id) { deployment in
                    PagesDeploymentRow(
                        deployment: deployment,
                        isPerformingAction: isPerformingAction,
                        onShowLogs: {
                            selectedDeploymentForLogs = deployment
                        },
                        onRetry: {
                            Task {
                                await retryDeployment(deployment)
                            }
                        },
                        onRollback: deployment.canRollback ? {
                            deploymentPendingRollback = deployment
                        } : nil,
                        onDelete: isAdvancedDangerousModeEnabled ? {
                            deploymentPendingDeletion = deployment
                        } : nil
                    )
                }
            }
        }
    }

    private func loadDeployments() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let deployments = try await pagesDeploymentsViewModel.loadPagesDeployments(projectName: project.name)
            productionDeployments = deployments.filter { $0.environment?.lowercased() == "production" }
            previewDeployments = deployments.filter { $0.environment?.lowercased() != "production" }
            statusMessage = deployments.isEmpty ? nil : "Showing the latest deployment page returned by Cloudflare."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func retryDeployment(_ deployment: PagesDeployment) async {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            _ = try await pagesDeploymentsViewModel.retryPagesDeployment(
                projectName: project.name,
                deploymentID: deployment.id
            )
            statusMessage = "Deployment retry submitted."
            await loadDeployments()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func rollbackDeployment(_ deployment: PagesDeployment) async {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm rollback of Pages project \(project.name)."
            )
            _ = try await pagesDeploymentsViewModel.rollbackPagesDeployment(
                projectName: project.name,
                deploymentID: deployment.id
            )
            statusMessage = "Rollback submitted."
            await loadDeployments()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteDeployment(_ deployment: PagesDeployment) async {
        isPerformingAction = true
        defer {
            isPerformingAction = false
            deploymentPendingDeletion = nil
        }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm deletion of Pages deployment \(deployment.id)."
            )
            try await pagesDeploymentsViewModel.deletePagesDeployment(
                projectName: project.name,
                deploymentID: deployment.id
            )
            productionDeployments.removeAll { $0.id == deployment.id }
            previewDeployments.removeAll { $0.id == deployment.id }
            statusMessage = "Deployment deleted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private var rollbackConfirmationMessage: String {
        guard let deployment = deploymentPendingRollback else {
            return ""
        }

        let created = deployment.createdOn?.formatted(date: .abbreviated, time: .shortened) ?? deployment.id
        return DangerousOperationMessage.liveChange(
            resource: "Pages deployment",
            name: project.name,
            from: "current \(deployment.environmentTitle) deployment",
            to: created,
            impact: "Cloudflare will route \(deployment.environmentTitle.lowercased()) traffic back to this deployment. Visitors can immediately see older code or assets."
        )
    }

    private var deploymentDeletionMessage: String {
        guard let deployment = deploymentPendingDeletion else {
            return ""
        }

        let created = deployment.createdOn?.formatted(date: .abbreviated, time: .shortened) ?? deployment.id
        return DangerousOperationMessage.destructive(
            resource: "Pages deployment",
            name: deployment.id,
            scope: "\(project.name) / \(deployment.environmentTitle)",
            impact: "Cloudflare will remove the deployment record created \(created). Logs and rollback access for this deployment can disappear."
        )
    }
}
