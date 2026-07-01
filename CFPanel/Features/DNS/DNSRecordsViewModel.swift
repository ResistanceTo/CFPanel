import Foundation
import Observation

@MainActor
@Observable
final class DNSRecordsViewModel {
    @ObservationIgnored
    private let store: DNSStore
    @ObservationIgnored
    private let context: DNSWorkspaceContext

    init(store: DNSStore, context: DNSWorkspaceContext) {
        self.store = store
        self.context = context
    }

    var records: [DNSRecord] {
        store.records
    }

    var searchText: String {
        get { store.searchText }
        set { store.searchText = newValue }
    }

    var typeFilter: DNSRecordTypeFilter {
        get { store.typeFilter }
        set { store.typeFilter = newValue }
    }

    var proxyFilter: DNSProxyFilter {
        get { store.proxyFilter }
        set { store.proxyFilter = newValue }
    }

    var riskFilter: DNSRiskFilter {
        get { store.riskFilter }
        set { store.riskFilter = newValue }
    }

    var editor: DNSRecordDraft? {
        get { store.editor }
        set { store.editor = newValue }
    }

    var filteredRecords: [DNSRecord] {
        store.filteredRecords
    }

    var inventorySummary: DNSInventorySummary {
        store.inventorySummary
    }

    var riskSummary: DNSRiskSummary {
        store.riskSummary
    }

    var selectedZoneID: String? {
        context.selectedZoneID
    }

    var selectedZone: CloudflareZone? {
        context.selectedZone
    }

    var tokenVerification: TokenVerification? {
        context.tokenVerification
    }

    var lastRefreshAt: Date? {
        context.lastRefreshAt
    }

    var isRefreshing: Bool {
        context.isRefreshingDNS
    }

    func isLoaded(for zoneID: String) -> Bool {
        context.isDNSLoaded(for: zoneID)
    }

    func presentError(_ error: some Error) {
        context.presentError(error)
    }

    func saveRecord(_ draft: DNSRecordDraft) async {
        guard let zoneID = selectedZoneID else { return }

        do {
            if let recordID = draft.recordID {
                _ = try await context.api.updateDNSRecord(zoneID: zoneID, recordID: recordID, draft: draft)
                context.presentNotice("DNS record updated.")
            } else {
                _ = try await context.api.createDNSRecord(zoneID: zoneID, draft: draft)
                context.presentNotice("DNS record created.")
            }

            editor = nil
            try await refresh()
        } catch {
            context.presentError(error)
        }
    }

    func deleteRecord(_ record: DNSRecord) async {
        guard let zoneID = selectedZoneID else { return }

        do {
            try await context.api.deleteDNSRecord(zoneID: zoneID, recordID: record.id)
            try await refresh()
            context.presentNotice("DNS record deleted.")
        } catch {
            context.presentError(error)
        }
    }

    func refresh() async throws {
        guard let requestContext = context.makeZoneRequestContext() else { return }

        try await context.withDNSRefresh {
            let resolvedRecords = try await context.api.listDNSRecords(zoneID: requestContext.zoneID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale DNS records response.")
                return
            }

            store.records = resolvedRecords
            context.markDNSLoaded(zoneID: requestContext.zoneID)
        }
    }
}
