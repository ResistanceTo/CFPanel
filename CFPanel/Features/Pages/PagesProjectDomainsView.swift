import SwiftUI

struct PagesProjectDomainsView: View {
    @Environment(PagesDomainsViewModel.self) private var pagesDomainsViewModel
    let project: PagesProject

    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false
    @State private var domains: [PagesProjectDomain] = []
    @State private var isLoading = false
    @State private var isPerformingAction = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var newDomainName = ""
    @State private var domainPendingDeletion: PagesProjectDomain?

    var body: some View {
        List {
            contextSection
            addDomainSection
            statusSection
            domainsSection
        }
        .navigationTitle("Custom Domains")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: project.id) {
            await loadDomains()
        }
        .refreshable {
            await loadDomains()
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
                await deleteDomain(domainPendingDeletion)
                self.domainPendingDeletion = nil
            }
        }
    }

    private var contextSection: some View {
        Section("Project") {
            LabeledContent("Name", value: project.name)
            Text("Custom domains load here on demand so project operation pages stay lightweight.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var addDomainSection: some View {
        Section("Add Domain") {
            TextField("app.example.com", text: $newDomainName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

            Button("Attach Domain") {
                Task {
                    await createDomain()
                }
            }
            .disabled(newDomainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPerformingAction)

            Text("Create the domain here, then use the validation details below to finish DNS setup if Cloudflare requires it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage {
            Section("Status") {
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage {
            Section("Status") {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var domainsSection: some View {
        Section("Domains") {
            if isLoading && domains.isEmpty {
                ProgressView("Loading Domains")
            } else if domains.isEmpty {
                Text("No custom domains attached.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(domains) { domain in
                    VStack(alignment: .leading, spacing: 8) {
                        PagesDomainRow(
                            domain: domain,
                            isPerformingAction: isPerformingAction,
                            onRetryValidation: {
                                Task {
                                    await retryValidation(for: domain)
                                }
                            }
                        )

                        HStack {
                            Spacer(minLength: 0)

                            if isAdvancedDangerousModeEnabled {
                                Button("Delete Domain", role: .destructive) {
                                    domainPendingDeletion = domain
                                }
                                .disabled(isPerformingAction)
                                .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }
        }
    }

    private func createDomain() async {
        let domainName = newDomainName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard domainName.isEmpty == false else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            _ = try await pagesDomainsViewModel.createPagesDomain(projectName: project.name, domainName: domainName)
            newDomainName = ""
            statusMessage = "Domain attached."
            await loadDomains()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadDomains() async {
        isLoading = true
        defer { isLoading = false }

        do {
            domains = try await pagesDomainsViewModel.loadPagesDomains(projectName: project.name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func retryValidation(for domain: PagesProjectDomain) async {
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            _ = try await pagesDomainsViewModel.retryPagesDomainValidation(
                projectName: project.name,
                domainName: domain.name
            )
            statusMessage = "Domain validation retried for \(domain.name)."
            await loadDomains()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteDomain(_ domain: PagesProjectDomain) async {
        isPerformingAction = true
        defer {
            isPerformingAction = false
            domainPendingDeletion = nil
        }

        do {
            try await DangerousActionAuthorizer.authorize(
                reason: "Confirm deletion of Pages custom domain \(domain.name)."
            )
            try await pagesDomainsViewModel.deletePagesDomain(projectName: project.name, domainName: domain.name)
            domains.removeAll { $0.id == domain.id }
            statusMessage = "Domain deleted."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private var domainDeletionMessage: String {
        guard let domain = domainPendingDeletion else {
            return ""
        }

        return DangerousOperationMessage.destructive(
            resource: "Pages custom domain",
            name: domain.name,
            scope: project.name,
            impact: "Cloudflare will detach this hostname from the Pages project. Visitor traffic to this domain can stop reaching the project immediately."
        )
    }
}
