import Foundation
import SwiftUI

nonisolated enum DNSRecordTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case a
    case aaaa
    case cname
    case mx
    case txt
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Types"
        case .a: "A"
        case .aaaa: "AAAA"
        case .cname: "CNAME"
        case .mx: "MX"
        case .txt: "TXT"
        case .other: "Other"
        }
    }

    func matches(_ record: DNSRecord) -> Bool {
        switch self {
        case .all:
            true
        case .a:
            record.normalizedType == "A"
        case .aaaa:
            record.normalizedType == "AAAA"
        case .cname:
            record.normalizedType == "CNAME"
        case .mx:
            record.normalizedType == "MX"
        case .txt:
            record.normalizedType == "TXT"
        case .other:
            SupportedDNSRecordType(rawValue: record.normalizedType) == nil
        }
    }
}

nonisolated enum DNSProxyFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case proxied
    case dnsOnly

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All Exposure"
        case .proxied: "Proxied"
        case .dnsOnly: "DNS Only"
        }
    }

    func matches(_ record: DNSRecord) -> Bool {
        switch self {
        case .all:
            true
        case .proxied:
            record.proxied == true
        case .dnsOnly:
            record.proxied == false
        }
    }
}

nonisolated enum DNSRiskFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case attentionOnly

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All Records"
        case .attentionOnly: "Attention Only"
        }
    }

    func matches(_ record: DNSRecord) -> Bool {
        switch self {
        case .all:
            true
        case .attentionOnly:
            record.needsAttention
        }
    }
}

nonisolated struct DNSInventorySummary: Sendable, Equatable {
    let totalRecords: Int
    let proxiedRecords: Int
    let unsupportedRecords: Int
    let topRecordTypes: [String]

    static let empty = DNSInventorySummary(
        totalRecords: 0,
        proxiedRecords: 0,
        unsupportedRecords: 0,
        topRecordTypes: []
    )
}

nonisolated struct DNSRiskSummary: Sendable, Equatable {
    let dnsOnlyWebRecords: Int
    let wildcardRecords: Int
    let unsupportedRecords: Int

    var totalAttentionItems: Int {
        dnsOnlyWebRecords + wildcardRecords + unsupportedRecords
    }

    static let empty = DNSRiskSummary(
        dnsOnlyWebRecords: 0,
        wildcardRecords: 0,
        unsupportedRecords: 0
    )
}
