import SwiftUI

struct DNSRecordsView: View {
    @Environment(DNSRecordsViewModel.self) private var dnsRecordsViewModel
    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false
    @State private var detailRecord: DNSRecord?
    @State private var rawRecord: DNSRecord?
    @State private var recordPendingDeletion: DNSRecord?

    var body: some View {
        @Bindable var dnsRecordsViewModel = dnsRecordsViewModel
        let filteredRecords = dnsRecordsViewModel.filteredRecords
        let riskSummary = dnsRecordsViewModel.riskSummary
        let totalRecordCount = dnsRecordsViewModel.records.count

        List {
            Section {
                ZoneContextCard(
                    zone: dnsRecordsViewModel.selectedZone,
                    tokenVerification: dnsRecordsViewModel.tokenVerification,
                    lastRefreshAt: dnsRecordsViewModel.lastRefreshAt,
                    recordCount: totalRecordCount
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Filters") {
                Picker("Type", selection: $dnsRecordsViewModel.typeFilter) {
                    ForEach(DNSRecordTypeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Picker("Exposure", selection: $dnsRecordsViewModel.proxyFilter) {
                    ForEach(DNSProxyFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Picker("Scope", selection: $dnsRecordsViewModel.riskFilter) {
                    ForEach(DNSRiskFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
            }

            Section("Attention") {
                DNSRiskSummaryCard(summary: riskSummary)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                if dnsRecordsViewModel.isRefreshing && filteredRecords.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Loading DNS")
                        Spacer()
                    }
                } else if filteredRecords.isEmpty {
                    ContentUnavailableView(
                        "No DNS Records",
                        systemImage: "network",
                        description: Text("The selected zone has no records matching your filter.")
                    )
                }

                ForEach(filteredRecords) { record in
                    Button {
                        detailRecord = record
                    } label: {
                        DNSRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if isAdvancedDangerousModeEnabled, record.supportedType != nil {
                            Button("Delete", role: .destructive) {
                                recordPendingDeletion = record
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("DNS")
        .task(id: dnsRecordsViewModel.selectedZoneID) {
            guard let zoneID = dnsRecordsViewModel.selectedZoneID else { return }
            guard dnsRecordsViewModel.isLoaded(for: zoneID) == false else { return }
            do {
                try await dnsRecordsViewModel.refresh()
            } catch {
                dnsRecordsViewModel.presentError(error)
            }
        }
        .searchable(text: $dnsRecordsViewModel.searchText, prompt: "Search records")
        .refreshable {
            do {
                try await dnsRecordsViewModel.refresh()
            } catch {
                dnsRecordsViewModel.presentError(error)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    NavigationLink {
                        DNSScanReviewView()
                    } label: {
                        Label("DNS Discovery", systemImage: "magnifyingglass.circle")
                    }

                    NavigationLink {
                        DNSZoneFileView()
                    } label: {
                        Label("Zone File", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More DNS actions")
                .disabled(dnsRecordsViewModel.selectedZoneID == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dnsRecordsViewModel.editor = DNSRecordDraft()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add DNS record")
                .disabled(dnsRecordsViewModel.selectedZoneID == nil)
            }
        }
        .sheet(item: $dnsRecordsViewModel.editor) { draft in
            DNSRecordEditorView(draft: draft)
        }
        .sheet(item: $detailRecord) { record in
            DNSRecordDetailView(
                record: record,
                showRawJSON: {
                    rawRecord = record
                },
                editRecord: {
                    if record.supportedType != nil {
                        dnsRecordsViewModel.editor = DNSRecordDraft(record: record)
                    } else {
                        rawRecord = record
                    }
                }
            )
        }
        .sheet(item: $rawRecord) { record in
            DNSRecordPayloadView(record: record)
        }
        .countdownConfirmationDialog(
            "Delete this DNS record?",
            isPresented: Binding(
                get: { recordPendingDeletion != nil },
                set: { newValue in
                    if newValue == false {
                        recordPendingDeletion = nil
                    }
                }
            ),
            message: dnsDeletionMessage,
            actionTitle: "Delete Record",
            onCancel: {
                recordPendingDeletion = nil
            }
        ) {
            guard let deletingRecord = recordPendingDeletion else { return }
            Task {
                do {
                    try await DangerousActionAuthorizer.authorize(
                        reason: "Confirm deletion of DNS record \(deletingRecord.name)."
                    )
                    await dnsRecordsViewModel.deleteRecord(deletingRecord)
                    recordPendingDeletion = nil
                } catch {
                    dnsRecordsViewModel.presentError(error)
                }
            }
        }
    }

    private var dnsDeletionMessage: String {
        guard let record = recordPendingDeletion else {
            return ""
        }

        return DangerousOperationMessage.destructive(
            resource: "DNS record",
            name: "\(record.type) \(record.name)",
            scope: dnsRecordsViewModel.selectedZone?.name,
            impact: "Cloudflare will stop serving this record. Traffic, mail, or verification flows using \(record.content ?? "this value") can break immediately."
        )
    }
}
