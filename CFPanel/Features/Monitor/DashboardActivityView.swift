import SwiftUI

struct DashboardActivityView: View {
    @Environment(AuditLogViewModel.self) private var auditLogViewModel
    @AppStorage("dashboard_activity_range") private var rangeRaw: String = AuditLogTimeRange.last7Days.rawValue
    @AppStorage("dashboard_activity_scope") private var scopeRaw: String = AuditLogScope.currentZone.rawValue

    @State private var page: AuditLogPage?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            controlsSection
            summarySection
            entriesSection
        }
        .navigationTitle("Audit Log")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: loadKey) {
            await loadActivity()
        }
        .refreshable {
            await loadActivity()
        }
    }

    private var loadKey: String {
        "\(auditLogViewModel.resolvedAccountID ?? ""):\(selectedRange.rawValue):\(selectedScope.rawValue):\(auditLogViewModel.selectedZoneID ?? "")"
    }

    private var selectedRange: AuditLogTimeRange {
        AuditLogTimeRange(rawValue: rangeRaw) ?? .last7Days
    }

    private var selectedScope: AuditLogScope {
        let resolved = AuditLogScope(rawValue: scopeRaw) ?? .currentZone
        if resolved == .currentZone, auditLogViewModel.selectedZoneID == nil {
            return .account
        }
        return resolved
    }

    private var controlsSection: some View {
        Section("Filters") {
            Picker("Range", selection: $rangeRaw) {
                ForEach(AuditLogTimeRange.allCases) { range in
                    Text(range.title).tag(range.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if auditLogViewModel.selectedZoneID != nil {
                Picker("Scope", selection: $scopeRaw) {
                    ForEach(AuditLogScope.allCases) { scope in
                        Text(scope.title).tag(scope.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                LabeledContent("Scope", value: "Account")
            }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            if let accountID = auditLogViewModel.resolvedAccountID {
                LabeledContent {
                    Text(accountID.middleEllipsizedToken)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("Account")
                }
            }
            if selectedScope == .currentZone, let zone = auditLogViewModel.selectedZone {
                LabeledContent {
                    Text(zone.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                } label: {
                    Text("Zone")
                }
            }
            if let count = page?.resultInfo?.count {
                LabeledContent("Returned", value: count.formatted())
            }
            Text("This page loads account activity only when you open it. Tap a row for full details without making another list request.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var entriesSection: some View {
        Section("Audit Logs") {
            if isLoading && page == nil {
                ProgressView("Loading Audit Log")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else if let entries = page?.entries, entries.isEmpty == false {
                ForEach(entries) { entry in
                    NavigationLink {
                        AuditLogEntryDetailView(entry: entry)
                    } label: {
                        AuditLogEntryRow(entry: entry)
                    }
                }
            } else {
                Text("No activity entries were returned for the selected filters.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadActivity() async {
        isLoading = true
        defer { isLoading = false }

        do {
            page = try await auditLogViewModel.loadAuditLogPage(
                range: selectedRange,
                scope: selectedScope
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AuditLogEntryRow: View {
    let entry: AuditLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(entry.resourceTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                RulesBadgeView(title: entry.resultTitle, tint: entry.resultTint)
            }

            Text(entry.actorTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 12) {
                if let interfaceTitle = entry.interfaceTitle {
                    Text(interfaceTitle)
                        .lineLimit(1)
                }
                if let when = entry.when {
                    Text(when.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct AuditLogEntryDetailView: View {
    let entry: AuditLogEntry

    var body: some View {
        List {
            Section("Action") {
                LabeledContent("Type", value: entry.actionTitle)
                LabeledContent("Result", value: entry.resultTitle)
                if let when = entry.when {
                    LabeledContent("When", value: when.formatted(date: .abbreviated, time: .shortened))
                }
                if let interfaceTitle = entry.interfaceTitle {
                    LabeledContent("Interface", value: interfaceTitle)
                }
            }

            Section("Actor") {
                LabeledContent("Actor", value: entry.actorTitle)
                if let ip = entry.actor?.ip, ip.isEmpty == false {
                    LabeledContent("IP", value: ip)
                }
                if let actorID = entry.actor?.id, actorID.isEmpty == false {
                    LabeledContent {
                        Text(actorID)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.middle)
                    } label: {
                        Text("Actor ID")
                    }
                }
            }

            Section("Resource") {
                LabeledContent("Resource", value: entry.resourceTitle)
                if let type = entry.resource?.type, type.isEmpty == false {
                    LabeledContent("Resource Type", value: type.replacingOccurrences(of: "_", with: " ").localizedCapitalized)
                }
                if let resourceID = entry.resource?.id, resourceID.isEmpty == false {
                    LabeledContent {
                        Text(resourceID)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.middle)
                    } label: {
                        Text("Resource ID")
                    }
                }
                if let zoneName = entry.zone?.name, zoneName.isEmpty == false {
                    LabeledContent("Zone", value: zoneName)
                }
                if let zoneID = entry.zone?.id, zoneID.isEmpty == false {
                    LabeledContent {
                        Text(zoneID)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.middle)
                    } label: {
                        Text("Zone ID")
                    }
                }
            }

            if let metadata = entry.metadata {
                Section("Metadata") {
                    Text(metadata.prettyPrintedString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(entry.actionTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
