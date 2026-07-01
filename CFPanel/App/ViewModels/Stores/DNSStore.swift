import Foundation
import Observation

@MainActor
@Observable
final class DNSStore {
    var records: [DNSRecord] = [] {
        didSet {
            derivedState.invalidateRecords()
        }
    }
    var searchText = "" {
        didSet {
            derivedState.invalidateFilteredRecords()
        }
    }
    var typeFilter: DNSRecordTypeFilter = .all {
        didSet {
            derivedState.invalidateFilteredRecords()
        }
    }
    var proxyFilter: DNSProxyFilter = .all {
        didSet {
            derivedState.invalidateFilteredRecords()
        }
    }
    var riskFilter: DNSRiskFilter = .all {
        didSet {
            derivedState.invalidateFilteredRecords()
        }
    }
    var editor: DNSRecordDraft?

    @ObservationIgnored
    private var derivedState = DNSDerivedState()

    var filteredRecords: [DNSRecord] {
        derivedState.filteredRecords(
            from: records,
            searchText: searchText,
            typeFilter: typeFilter,
            proxyFilter: proxyFilter,
            riskFilter: riskFilter
        )
    }

    var inventorySummary: DNSInventorySummary {
        derivedState.inventorySummary(from: records)
    }

    var riskSummary: DNSRiskSummary {
        derivedState.riskSummary(from: records)
    }

    func reset() {
        records = []
        searchText = ""
        typeFilter = .all
        proxyFilter = .all
        riskFilter = .all
        editor = nil
    }
}
