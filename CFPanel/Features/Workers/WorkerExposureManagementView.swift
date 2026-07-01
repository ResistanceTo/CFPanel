import SwiftUI

struct WorkerExposureManagementView: View {
    @Environment(WorkerExposureViewModel.self) private var workerExposureViewModel
    let runtime: WorkerRuntimeSummary

    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false
    @State private var snapshot: WorkerExposureManagementSnapshot?
    @State private var isLoading = false
    @State private var isPerformingAction = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var newRoutePattern = ""
    @State private var newCustomDomain = ""
    @State private var routePendingDeletion: WorkerRoute?
    @State private var domainPendingDeletion: WorkerDomain?
    @State private var routeEditor: WorkerRouteEditorState?
    @State private var isConfirmingWorkersDevDisable = false

    var body: some View {
        Form {
            WorkerExposureContextSection(
                scriptID: runtime.script.id,
                zoneName: workerExposureViewModel.selectedZone?.name
            )

            operationalNotesSection
            workersDevSection
            routesSection
            customDomainsSection

            if let statusMessage {
                WorkerExposureNoticeSection(title: "Status", message: statusMessage)
            }

            if let errorMessage {
                WorkerExposureNoticeSection(title: "Error", message: errorMessage)
            }
        }
        .navigationTitle("Manage Exposure")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: runtime.id) {
            await loadExposure()
        }
        .refreshable {
            await loadExposure()
        }
        .sheet(item: $routeEditor) { editor in
            WorkerRouteEditorSheet(
                route: editor.route,
                pattern: editor.pattern,
                isSaving: isPerformingAction,
                onSave: { updatedPattern in
                    await saveRoute(route: editor.route, pattern: updatedPattern)
                }
            )
        }
        .countdownConfirmationDialog(
            "Delete this route?",
            isPresented: Binding(
                get: { routePendingDeletion != nil },
                set: { newValue in
                    if newValue == false {
                        routePendingDeletion = nil
                    }
                }
            ),
            message: routeDeletionMessage,
            actionTitle: "Delete Route",
            onCancel: {
                routePendingDeletion = nil
            }
        ) {
            guard let routePendingDeletion else { return }
            Task {
                await deleteRoute(routePendingDeletion)
                self.routePendingDeletion = nil
            }
        }
        .countdownConfirmationDialog(
            "Delete this custom domain?",
            isPresented: Binding(
                get: { domainPendingDeletion != nil },
                set: { newValue in
                    if newValue == false {
                        domainPendingDeletion = nil
                    }
                }
            ),
            message: domainDeletionMessage,
            actionTitle: "Delete Domain",
            onCancel: {
                domainPendingDeletion = nil
            }
        ) {
            guard let domainPendingDeletion else { return }
            Task {
                await deleteCustomDomain(domainPendingDeletion)
                self.domainPendingDeletion = nil
            }
        }
        .countdownConfirmationDialog(
            "Delete workers.dev binding?",
            isPresented: $isConfirmingWorkersDevDisable,
            message: workersDevDeletionMessage,
            actionTitle: "Delete workers.dev Binding",
            role: .destructive
        ) {
            Task {
                await deleteWorkersDevRoute()
            }
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
    private var workersDevSection: some View {
        Section("workers.dev") {
            if isLoading && snapshot == nil {
                ProgressView("Loading workers.dev settings")
            } else if snapshot?.subdomainStatus.enabled == true {
                LabeledContent("Status", value: "Published on workers.dev")

                Toggle(
                    "Enable Preview URLs",
                    isOn: Binding(
                        get: { snapshot?.subdomainStatus.previewsEnabled ?? false },
                        set: { newValue in
                            Task {
                                await updateWorkersDev(
                                    enabled: snapshot?.subdomainStatus.enabled ?? false,
                                    previewsEnabled: newValue
                                )
                            }
                        }
                    )
                )
                .disabled(snapshot?.subdomainStatus.enabled != true || isPerformingAction)

                if isAdvancedDangerousModeEnabled {
                    Button("Delete workers.dev Binding", role: .destructive) {
                        isConfirmingWorkersDevDisable = true
                    }
                    .disabled(snapshot == nil || isPerformingAction)
                }

                if let workersDevURL = snapshot?.workersDevURL {
                    if let destination = URL(string: "https://\(workersDevURL)") {
                        Link(workersDevURL, destination: destination)
                            .font(.system(.footnote, design: .monospaced))
                    } else {
                        Text(workersDevURL)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text("Deleting this binding removes the public workers.dev hostname for this script. Re-enable it later with the button below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("workers.dev hostname unavailable for this account token.")
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("Status", value: "No workers.dev route")

                Button("Enable workers.dev Binding") {
                    Task {
                        await updateWorkersDev(enabled: true, previewsEnabled: snapshot?.subdomainStatus.previewsEnabled ?? false)
                    }
                }
                .disabled(snapshot == nil || isPerformingAction)

                Text("This creates a public workers.dev hostname for this script. Removing it later uses Cloudflare's delete endpoint and is shown as a delete action.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var routesSection: some View {
        Section {
            if workerExposureViewModel.selectedZoneID == nil {
                Text("Select a zone before managing Worker routes.")
                    .foregroundStyle(.secondary)
            } else {
                TextField("example.com/*", text: $newRoutePattern)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))

                Button("Add Route") {
                    Task {
                        await createRoute()
                    }
                }
                .disabled(newRoutePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPerformingAction)

                if isLoading && snapshot == nil {
                    ProgressView("Loading Routes")
                } else if snapshot?.routeAvailabilityKnown == false {
                    Text("Route visibility is unavailable for this zone or token.")
                        .foregroundStyle(.secondary)
                } else if let routes = snapshot?.resolvedRoutes, routes.isEmpty == false {
                    ForEach(routes) { route in
                        WorkerRouteManagementRow(
                            route: route,
                            scriptID: runtime.script.id,
                            isDangerousModeEnabled: isAdvancedDangerousModeEnabled,
                            isPerformingAction: isPerformingAction,
                            onEdit: {
                                routeEditor = WorkerRouteEditorState(route: route, pattern: route.pattern)
                            },
                            onDelete: {
                                routePendingDeletion = route
                            }
                        )
                    }
                } else {
                    Text("No routes are attached to this script in the selected zone.")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Zone Routes")
        } footer: {
            Text("Use host or wildcard patterns such as `example.com/*` or `api.example.com/*`.")
        }
    }

    @ViewBuilder
    private var customDomainsSection: some View {
        Section {
            if workerExposureViewModel.selectedZoneID == nil {
                Text("Select a zone before attaching Worker custom domains.")
                    .foregroundStyle(.secondary)
            } else {
                TextField("app.example.com", text: $newCustomDomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))

                Button("Attach Domain") {
                    Task {
                        await attachCustomDomain()
                    }
                }
                .disabled(newCustomDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPerformingAction)

                if isLoading && snapshot == nil {
                    ProgressView("Loading Domains")
                } else if snapshot?.domainAvailabilityKnown == false {
                    Text("Custom domain visibility is unavailable for this token.")
                        .foregroundStyle(.secondary)
                } else if let domains = snapshot?.resolvedDomains, domains.isEmpty == false {
                    ForEach(domains, id: \.listID) { domain in
                        WorkerCustomDomainManagementRow(
                            domain: domain,
                            scriptID: runtime.script.id,
                            isDangerousModeEnabled: isAdvancedDangerousModeEnabled,
                            isPerformingAction: isPerformingAction,
                            onDelete: {
                                domainPendingDeletion = domain
                            }
                        )
                    }
                } else if snapshot != nil {
                    Text("No custom domains are attached to this script.")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Custom Domains")
        } footer: {
            Text("Attach hostnames in the selected zone, such as `app.example.com`.")
        }
    }

    private func loadExposure() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await workerExposureViewModel.loadWorkerExposureManagement(scriptName: runtime.script.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var workersDevDeletionMessage: String {
        let target = snapshot?.workersDevURL ?? runtime.script.id
        return DangerousOperationMessage.destructive(
            resource: "workers.dev binding",
            name: target,
            scope: runtime.script.id,
            impact: "Cloudflare will remove the public workers.dev hostname for this script. Existing zone routes and custom domains are not deleted."
        )
    }

    private var routeDeletionMessage: String {
        guard let route = routePendingDeletion else {
            return ""
        }

        return DangerousOperationMessage.destructive(
            resource: "Worker route",
            name: route.pattern,
            scope: workerExposureViewModel.selectedZone?.name,
            impact: "Cloudflare will stop routing matching traffic to \(route.script ?? runtime.script.id)."
        )
    }

    private var domainDeletionMessage: String {
        guard let domain = domainPendingDeletion else {
            return ""
        }

        return DangerousOperationMessage.destructive(
            resource: "Worker custom domain",
            name: domain.hostname ?? domain.id ?? "custom domain",
            scope: runtime.script.id,
            impact: "Cloudflare will detach this hostname from the Worker. Visitor traffic to this domain can stop reaching the script immediately."
        )
    }

    private func updateWorkersDev(enabled: Bool, previewsEnabled: Bool) async {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            _ = try await workerExposureViewModel.updateWorkerSubdomain(
                scriptName: runtime.script.id,
                enabled: enabled,
                previewsEnabled: previewsEnabled
            )
            statusMessage = enabled
                ? "workers.dev exposure updated."
                : "workers.dev exposure disabled."
            await loadExposure()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteWorkersDevRoute() async {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm deletion of the workers.dev route for \(runtime.script.id)."
            )
            try await workerExposureViewModel.deleteWorkerSubdomain(scriptName: runtime.script.id)
            statusMessage = "workers.dev binding deleted."
            await loadExposure()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func createRoute() async {
        let pattern = newRoutePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pattern.isEmpty == false else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            _ = try await workerExposureViewModel.createWorkerRoute(scriptName: runtime.script.id, pattern: pattern)
            newRoutePattern = ""
            statusMessage = "Route created."
            await loadExposure()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func attachCustomDomain() async {
        let hostname = newCustomDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard hostname.isEmpty == false else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            _ = try await workerExposureViewModel.attachWorkerCustomDomain(
                scriptName: runtime.script.id,
                hostname: hostname
            )
            newCustomDomain = ""
            statusMessage = "Custom domain attached."
            await loadExposure()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteRoute(_ route: WorkerRoute) async {
        isPerformingAction = true
        defer {
            isPerformingAction = false
            routePendingDeletion = nil
        }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm deletion of Worker route \(route.pattern)."
            )
            try await workerExposureViewModel.deleteWorkerRoute(routeID: route.id)
            statusMessage = "Route deleted."
            await loadExposure()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveRoute(route: WorkerRoute, pattern: String) async {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPattern.isEmpty == false else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            _ = try await workerExposureViewModel.updateWorkerRoute(
                routeID: route.id,
                scriptName: runtime.script.id,
                pattern: trimmedPattern
            )
            routeEditor = nil
            statusMessage = "Route updated."
            await loadExposure()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteCustomDomain(_ domain: WorkerDomain) async {
        guard let domainID = domain.id, domainID.isEmpty == false else {
            return
        }

        isPerformingAction = true
        defer {
            isPerformingAction = false
            domainPendingDeletion = nil
        }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm deletion of Worker custom domain \(domain.hostname ?? domainID)."
            )
            try await workerExposureViewModel.deleteWorkerCustomDomain(domainID: domainID)
            statusMessage = "Custom domain deleted."
            await loadExposure()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private struct WorkerRouteEditorState: Identifiable {
    let route: WorkerRoute
    let pattern: String

    var id: String { route.id }
}

private struct WorkerRouteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let route: WorkerRoute
    let pattern: String
    let isSaving: Bool
    let onSave: @Sendable (String) async -> Void

    @State private var editedPattern: String

    init(
        route: WorkerRoute,
        pattern: String,
        isSaving: Bool,
        onSave: @escaping @Sendable (String) async -> Void
    ) {
        self.route = route
        self.pattern = pattern
        self.isSaving = isSaving
        self.onSave = onSave
        _editedPattern = State(initialValue: pattern)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Route") {
                    TextField("example.com/*", text: $editedPattern)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))

                    if let script = route.script, script.isEmpty == false {
                        LabeledContent("Script", value: script)
                    }
                }
            }
            .navigationTitle("Edit Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(editedPattern)
                        }
                    }
                    .disabled(editedPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }
}
