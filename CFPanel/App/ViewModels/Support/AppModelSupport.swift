import Foundation
import SwiftUI

struct AppLoadState {
    var dashboardKey: String?
    var zoneResources: Set<ZoneLoadResource> = []
    var accountResources: Set<AccountLoadResource> = []
    var rulesPhaseResources: Set<RulesPhaseLoadResource> = []
}

struct SessionRequestContext {
    let sessionRevision: UInt64
}

struct ZoneRequestContext {
    let sessionRevision: UInt64
    let zoneID: String
}

struct AccountRequestContext {
    let sessionRevision: UInt64
    let accountID: String
}

struct ResolvedAccountContext {
    let accountID: String
    let source: String
}

enum LoadingActivity: String {
    case dashboard = "dashboard refresh"
    case dns = "dns refresh"
    case mail = "mail refresh"
    case pages = "pages refresh"
    case workers = "workers refresh"
    case r2 = "r2 refresh"
    case d1 = "d1 refresh"
    case queues = "queues refresh"
    case kv = "kv refresh"
    case vectorize = "vectorize refresh"
    case hyperdrive = "hyperdrive refresh"
    case zoneControls = "zone controls refresh"
    case rules = "rules refresh"
    case panicAction = "panic action"
}

struct LoadingActivityState {
    private var counts: [LoadingActivity: Int] = [:]

    mutating func begin(_ activity: LoadingActivity) -> Int {
        let nextCount = (counts[activity] ?? 0) + 1
        counts[activity] = nextCount
        return nextCount
    }

    mutating func end(_ activity: LoadingActivity) -> Int {
        let currentCount = counts[activity] ?? 0
        let nextCount = max(currentCount - 1, 0)
        counts[activity] = nextCount
        return nextCount
    }

    func isActive(_ activity: LoadingActivity) -> Bool {
        (counts[activity] ?? 0) > 0
    }
}

struct DNSDerivedState {
    private var filteredRecordsCache: [DNSRecord] = []
    private var inventorySummaryCache: DNSInventorySummary = .empty
    private var riskSummaryCache: DNSRiskSummary = .empty
    private var hasFilteredRecords = false
    private var hasInventorySummary = false
    private var hasRiskSummary = false

    mutating func invalidateRecords() {
        hasFilteredRecords = false
        hasInventorySummary = false
        hasRiskSummary = false
    }

    mutating func invalidateFilteredRecords() {
        hasFilteredRecords = false
    }

    // DNS pages can render thousands of rows. Cache the derived snapshots so
    // repeated body evaluations do not re-scan the full record set each time.
    mutating func filteredRecords(
        from records: [DNSRecord],
        searchText: String,
        typeFilter: DNSRecordTypeFilter,
        proxyFilter: DNSProxyFilter,
        riskFilter: DNSRiskFilter
    ) -> [DNSRecord] {
        guard hasFilteredRecords == false else {
            return filteredRecordsCache
        }

        let resolvedRecords = records.filter { record in
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    record.name.localizedStandardContains(searchText)
                    || record.type.localizedStandardContains(searchText)
                    || record.summary.localizedStandardContains(searchText)
                    || (record.comment?.localizedStandardContains(searchText) == true)
            }

            return matchesSearch
                && typeFilter.matches(record)
                && proxyFilter.matches(record)
                && riskFilter.matches(record)
        }

        filteredRecordsCache = resolvedRecords
        hasFilteredRecords = true
        return resolvedRecords
    }

    mutating func inventorySummary(from records: [DNSRecord]) -> DNSInventorySummary {
        guard hasInventorySummary == false else {
            return inventorySummaryCache
        }

        guard records.isEmpty == false else {
            inventorySummaryCache = .empty
            hasInventorySummary = true
            return inventorySummaryCache
        }

        let grouped = Dictionary(grouping: records, by: { $0.type.uppercased() })
        let topTypes = grouped
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.key < rhs.key
                }
                return lhs.value.count > rhs.value.count
            }
            .prefix(3)
            .map { "\($0.key) \($0.value.count)" }

        inventorySummaryCache = DNSInventorySummary(
            totalRecords: records.count,
            proxiedRecords: records.filter { $0.proxied == true }.count,
            unsupportedRecords: records.filter { $0.supportedType == nil }.count,
            topRecordTypes: topTypes
        )
        hasInventorySummary = true
        return inventorySummaryCache
    }

    mutating func riskSummary(from records: [DNSRecord]) -> DNSRiskSummary {
        guard hasRiskSummary == false else {
            return riskSummaryCache
        }

        guard records.isEmpty == false else {
            riskSummaryCache = .empty
            hasRiskSummary = true
            return riskSummaryCache
        }

        riskSummaryCache = DNSRiskSummary(
            dnsOnlyWebRecords: records.filter(\.isDNSOnlyWebRecord).count,
            wildcardRecords: records.filter(\.isWildcard).count,
            unsupportedRecords: records.filter(\.isUnsupported).count
        )
        hasRiskSummary = true
        return riskSummaryCache
    }
}

struct RulesInventorySummaryCache {
    private var cachedSummary: RulesInventorySummary = .empty
    private var hasCachedSummary = false

    mutating func invalidate() {
        hasCachedSummary = false
    }

    mutating func summary(from states: [RulesPhaseState]) -> RulesInventorySummary {
        guard hasCachedSummary == false else {
            return cachedSummary
        }

        guard states.isEmpty == false else {
            cachedSummary = .empty
            hasCachedSummary = true
            return cachedSummary
        }

        cachedSummary = RulesInventorySummary(
            configuredPhases: states.filter(\.isConfigured).count,
            totalPhases: states.count,
            totalRules: states.reduce(0) { $0 + ($1.ruleset?.rules.count ?? 0) },
            disabledRules: states.reduce(0) { $0 + ($1.ruleset?.disabledRuleCount ?? 0) },
            executeRules: states.reduce(0) { $0 + ($1.ruleset?.executeRuleCount ?? 0) },
            errorPhases: states.filter { $0.errorMessage != nil }.count
        )
        hasCachedSummary = true
        return cachedSummary
    }
}

struct ZoneLoadResource: Hashable {
    let zoneID: String
    let resource: ZoneLoadResourceKind
}

enum ZoneLoadResourceKind: Hashable {
    case dns
    case security
    case dnsSettings
    case tls
    case hsts
    case caching
    case emailRouting
    case emailSending
    case edgeFeatures
    case settings
    case trafficControls
    case securityControls
    case zoneOverview
}

struct AccountLoadResource: Hashable {
    let accountID: String
    let resource: AccountLoadResourceKind
}

enum AccountLoadResourceKind: Hashable {
    case pages
    case workers
    case emailDestinationAddresses
    case product(AccountDataProduct)
}

struct RulesPhaseLoadResource: Hashable {
    let zoneID: String
    let phase: CloudflareRulesetPhase
}

struct AppAlert: Identifiable, Equatable {
    let id = UUID()
    let title: LocalizedStringResource
    let message: String
}

extension CloudflareRulesetPhase {
    static var defaultStates: [RulesPhaseState] {
        allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { RulesPhaseState(phase: $0, ruleset: nil, errorMessage: nil) }
    }
}
