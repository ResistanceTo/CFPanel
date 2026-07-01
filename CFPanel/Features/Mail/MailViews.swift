import SwiftUI

struct EmailRoutingWorkspaceView: View {
    @Environment(EmailRoutingViewModel.self) private var emailRoutingViewModel
    @State private var newDestinationEmail = ""
    @State private var catchAllDestinationEmail = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZoneContextCard(
                    zone: emailRoutingViewModel.selectedZone,
                    tokenVerification: emailRoutingViewModel.tokenVerification,
                    lastRefreshAt: emailRoutingViewModel.lastRefreshAt,
                    recordCount: nil
                )
                overviewCard
                dnsCard
                destinationAddressesCard
                catchAllCard
                routingRulesCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Email Routing")
        .task(id: workspaceLoadKey) {
            await reload()
        }
        .task(id: catchAllSyncKey) {
            syncCatchAllSelection()
        }
        .refreshable {
            await reload(force: true)
        }
    }

    private var workspaceLoadKey: String {
        "\(emailRoutingViewModel.selectedZoneID ?? ""):\(emailRoutingViewModel.resolvedAccountID ?? "")"
    }

    private var catchAllSyncKey: String {
        let currentForward = emailRoutingViewModel.routingCatchAll?.forwardAddresses.joined(separator: ",") ?? ""
        let addresses = verifiedDestinationAddresses.map(\.email).joined(separator: ",")
        return "\(currentForward):\(addresses)"
    }

    private var verifiedDestinationAddresses: [EmailRoutingDestinationAddress] {
        emailRoutingViewModel.destinationAddresses.filter(\.isVerified)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Receiving Mail")
                .font(.headline)

            Text("This page focuses on safe, high-frequency Email Routing tasks: setup checks, destination addresses, catch-all forwarding, and rule visibility.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatusPill(
                    title: "Status",
                    value: emailRoutingViewModel.routingSettings?.enabled == true ? "Enabled" : "Disabled"
                )
                StatusPill(
                    title: "Rules",
                    value: emailRoutingViewModel.routingRules.count.formatted()
                )
                StatusPill(
                    title: "Verified",
                    value: verifiedDestinationAddresses.count.formatted()
                )
            }

            if let status = emailRoutingViewModel.routingSettings?.status, status.isEmpty == false {
                Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let message = emailRoutingViewModel.routingStatusMessage, message.isEmpty == false {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if emailRoutingViewModel.routingSettings?.enabled != true {
                Button {
                    Task {
                        await emailRoutingViewModel.enableEmailRouting()
                    }
                } label: {
                    Label("Enable Email Routing", systemImage: "envelope.badge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(emailRoutingViewModel.isRefreshing)

                Text("Cloudflare will provision Email Routing and tell you which DNS records must exist before mail can flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var dnsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DNS Setup")
                .font(.headline)

            if emailRoutingViewModel.routingDNS.records.isEmpty && emailRoutingViewModel.routingDNS.errors.isEmpty {
                Text("No Email Routing DNS records are available yet.")
                    .foregroundStyle(.secondary)
            } else {
                if emailRoutingViewModel.routingDNS.errors.isEmpty == false {
                    ForEach(emailRoutingViewModel.routingDNS.errors) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }

                ForEach(emailRoutingViewModel.routingDNS.records) { record in
                    MailDNSRecordRow(record: record)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var destinationAddressesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Destination Addresses")
                .font(.headline)

            Text("Add inboxes that can receive forwarded mail. Cloudflare requires inbox verification before a destination can be used in rules.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TextField("name@example.com", text: $newDestinationEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.quinary, in: .rect(cornerRadius: 16))

                Button("Add") {
                    let email = newDestinationEmail
                    newDestinationEmail = ""
                    Task {
                        await emailRoutingViewModel.addEmailRoutingDestinationAddress(email)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(emailRoutingViewModel.isRefreshing || newDestinationEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let message = emailRoutingViewModel.destinationAddressesStatusMessage, message.isEmpty == false {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if emailRoutingViewModel.destinationAddresses.isEmpty {
                Text("No destination addresses configured.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(emailRoutingViewModel.destinationAddresses) { address in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: address.isVerified ? "checkmark.seal.fill" : "clock.badge")
                            .foregroundStyle(address.isVerified ? .green : .orange)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(address.email)
                                .font(.subheadline.weight(.semibold))
                            Text(address.isVerified ? "Verified and ready for routing rules." : "Pending inbox verification.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        runtimeBadge(
                            title: address.isVerified ? "Verified" : "Pending",
                            tint: address.isVerified ? .green : .orange
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.quinary, in: .rect(cornerRadius: 16))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var catchAllCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Catch-all")
                .font(.headline)

            if let catchAll = emailRoutingViewModel.routingCatchAll {
                Text(catchAll.forwardAddresses.isEmpty ? "A catch-all rule exists, but its forward target could not be resolved." : "Current target: \(catchAll.forwardAddresses.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("No catch-all rule is configured yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if verifiedDestinationAddresses.isEmpty {
                Text("Add and verify at least one destination address before configuring a catch-all.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Forward To", selection: $catchAllDestinationEmail) {
                    ForEach(verifiedDestinationAddresses) { address in
                        Text(address.email).tag(address.email)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    let destination = catchAllDestinationEmail
                    Task {
                        await emailRoutingViewModel.updateEmailRoutingCatchAll(destination: destination)
                    }
                } label: {
                    Label("Save Catch-all", systemImage: "arrowshape.turn.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(emailRoutingViewModel.isRefreshing || catchAllDestinationEmail.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var routingRulesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Routing Rules")
                .font(.headline)

            Text("Rules are shown read-only on mobile so you can audit routing safely without exposing destructive actions by default.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if emailRoutingViewModel.routingRules.isEmpty {
                Text("No explicit Email Routing rules found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(emailRoutingViewModel.routingRules) { rule in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(rule.matcherSummary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            runtimeBadge(
                                title: rule.enabled ? "Active" : "Disabled",
                                tint: rule.enabled ? .green : .orange
                            )
                        }

                        Text(rule.summaryText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.quinary, in: .rect(cornerRadius: 16))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private func reload(force: Bool = false) async {
        await emailRoutingViewModel.refreshEmailRoutingWorkspace(force: force)
        syncCatchAllSelection()
    }

    private func syncCatchAllSelection() {
        let currentForward = emailRoutingViewModel.routingCatchAll?.forwardAddresses.first ?? ""
        if verifiedDestinationAddresses.contains(where: { $0.email == currentForward }) {
            catchAllDestinationEmail = currentForward
        } else if catchAllDestinationEmail.isEmpty, let first = verifiedDestinationAddresses.first?.email {
            catchAllDestinationEmail = first
        }
    }
}

struct EmailSendingWorkspaceView: View {
    @Environment(EmailSendingViewModel.self) private var emailSendingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZoneContextCard(
                    zone: emailSendingViewModel.selectedZone,
                    tokenVerification: emailSendingViewModel.tokenVerification,
                    lastRefreshAt: emailSendingViewModel.lastRefreshAt,
                    recordCount: nil
                )
                overviewCard
                subdomainsCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Email Sending")
        .task(id: emailSendingViewModel.selectedZoneID ?? "") {
            await emailSendingViewModel.refreshEmailSendingCatalog()
        }
        .refreshable {
            await emailSendingViewModel.refreshEmailSendingCatalog(force: true)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sending Mail")
                .font(.headline)

            Text("This page focuses on sending subdomain visibility and DNS readiness. Creation and deletion stay off mobile by default.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatusPill(title: "Subdomains", value: emailSendingViewModel.sendingSubdomains.count.formatted())
                StatusPill(
                    title: "Status",
                    value: emailSendingViewModel.isSendingUnavailable
                        ? "Unavailable"
                        : (emailSendingViewModel.sendingSubdomains.isEmpty ? "Idle" : "Loaded")
                )
            }

            if let message = emailSendingViewModel.sendingStatusMessage, message.isEmpty == false {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var subdomainsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sending Subdomains")
                .font(.headline)

            if emailSendingViewModel.isRefreshing && emailSendingViewModel.sendingSubdomains.isEmpty {
                ProgressView("Loading Email Sending")
            } else if emailSendingViewModel.sendingSubdomains.isEmpty {
                Text(emailSendingViewModel.sendingStatusMessage ?? "No Email Sending subdomains found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(emailSendingViewModel.sendingSubdomains) { subdomain in
                    NavigationLink {
                        EmailSendingSubdomainDetailView(subdomain: subdomain)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "paperplane")
                                .foregroundStyle(.blue)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(subdomain.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(subdomain.name)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

private struct EmailSendingSubdomainDetailView: View {
    @Environment(EmailSendingViewModel.self) private var emailSendingViewModel
    let subdomain: EmailSendingSubdomain

    @State private var records: [EmailDNSRecord] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DNS Records")
                        .font(.headline)
                    Text("These DNS records are required for sending mail from this subdomain.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.background, in: .rect(cornerRadius: 24))

                if isLoading && records.isEmpty {
                    ProgressView("Loading DNS Records")
                        .frame(maxWidth: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if records.isEmpty {
                    Text("No DNS records returned for this subdomain.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(records) { record in
                            MailDNSRecordRow(record: record)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(subdomain.displayName)
        .task {
            await loadRecords()
        }
        .refreshable {
            await loadRecords()
        }
    }

    private func loadRecords() async {
        isLoading = true
        defer { isLoading = false }

        do {
            records = try await emailSendingViewModel.loadEmailSendingDNSRecords(subdomainID: subdomain.id)
            errorMessage = nil
        } catch {
            records = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct MailDNSRecordRow: View {
    let record: EmailDNSRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(record.content)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                runtimeBadge(title: record.type, tint: .blue)
            }

            Text("TTL \(record.ttlText)\(record.priority.map { "  ·  Priority \($0)" } ?? "")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quinary, in: .rect(cornerRadius: 16))
    }
}
