import SwiftUI

struct PagesProjectOperationsView: View {
    @Environment(PagesCatalogViewModel.self) private var pagesCatalogViewModel
    @Environment(PagesOperationsViewModel.self) private var pagesOperationsViewModel
    let project: PagesProject
    let onProjectDeleted: () -> Void

    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false
    @State private var isPerformingAction = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isConfirmingProjectDeletion = false
    @State private var isConfirmingBuildCachePurge = false

    var body: some View {
        Form {
            Section("Project") {
                LabeledContent("Name", value: project.name)
                if let productionBranch = project.productionBranch {
                    LabeledContent("Production Branch", value: productionBranch)
                }
                Text("This page only loads project-level management data when you open it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Operations") {
                Button("Purge Build Cache") {
                    isConfirmingBuildCachePurge = true
                }
                .disabled(isPerformingAction)
            }

            if isAdvancedDangerousModeEnabled {
                Section {
                    Button("Delete Project", role: .destructive) {
                        isConfirmingProjectDeletion = true
                    }
                    .disabled(isPerformingAction)
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Deleting a project is destructive and should be used only when you are sure the project is no longer needed.")
                }
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Project Operations")
        .navigationBarTitleDisplayMode(.inline)
        .countdownConfirmationDialog(
            "Delete this Pages project?",
            isPresented: $isConfirmingProjectDeletion,
            message: projectDeletionMessage,
            actionTitle: "Delete Project"
        ) {
            Task {
                await deleteProject()
            }
        }
        .countdownConfirmationDialog(
            "Purge Pages build cache?",
            isPresented: $isConfirmingBuildCachePurge,
            message: buildCachePurgeMessage,
            actionTitle: "Purge Build Cache",
            role: .destructive
        ) {
            Task {
                await purgeBuildCache()
            }
        }
    }

    private func purgeBuildCache() async {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm purging Pages build cache for \(project.name)."
            )
            try await pagesOperationsViewModel.purgePagesBuildCache(projectName: project.name)
            statusMessage = "Build cache purge submitted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteProject() async {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm deletion of Pages project \(project.name)."
            )
            try await pagesOperationsViewModel.deletePagesProject(projectName: project.name)
            await pagesCatalogViewModel.refreshPagesCatalog(force: true)
            onProjectDeleted()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private var projectDeletionMessage: String {
        DangerousOperationMessage.destructive(
            resource: "Pages project",
            name: project.name,
            impact: "Cloudflare will delete the project, deployments, and project-level configuration visible to this token."
        )
    }

    private var buildCachePurgeMessage: String {
        DangerousOperationMessage.destructive(
            resource: "Pages build cache",
            name: project.name,
            impact: "Cloudflare will clear build cache. The next build can take longer and re-fetch dependencies.",
            irreversible: false
        )
    }
}
