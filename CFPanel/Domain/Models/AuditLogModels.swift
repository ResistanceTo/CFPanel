import Foundation
import SwiftUI

nonisolated enum AuditLogTimeRange: String, CaseIterable, Identifiable, Hashable, Sendable {
    case last24Hours
    case last7Days
    case last30Days

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last24Hours:
            "24H"
        case .last7Days:
            "7D"
        case .last30Days:
            "30D"
        }
    }

    func sinceDate(relativeTo endDate: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)

        switch self {
        case .last24Hours:
            return calendar.date(byAdding: .hour, value: -24, to: endDate) ?? endDate
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        }
    }
}

nonisolated enum AuditLogScope: String, CaseIterable, Identifiable, Hashable, Sendable {
    case currentZone
    case account

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .currentZone:
            "Current Zone"
        case .account:
            "Account"
        }
    }
}

nonisolated struct AuditLogPage: Sendable {
    let entries: [AuditLogEntry]
    let resultInfo: CloudflareResultInfo?
}

nonisolated struct AuditLogEntry: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let when: Date?
    let action: AuditLogAction?
    let actor: AuditLogActor?
    let resource: AuditLogResource?
    let zone: AuditLogZone?
    let interface: String?
    let metadata: JSONValue?

    var actionTitle: String {
        action?.type?
            .replacingOccurrences(of: "_", with: " ")
            .localizedCapitalized
            ?? "Unknown Action"
    }

    var resultTitle: String {
        action?.result?
            .replacingOccurrences(of: "_", with: " ")
            .localizedCapitalized
            ?? "Unknown"
    }

    var actorTitle: String {
        if let email = actor?.email, email.isEmpty == false {
            return email
        }
        if let ip = actor?.ip, ip.isEmpty == false {
            return ip
        }
        if let id = actor?.id, id.isEmpty == false {
            return id.middleEllipsizedToken
        }
        return "Unknown Actor"
    }

    var resourceTitle: String {
        if let name = resource?.name, name.isEmpty == false {
            return name
        }
        if let zoneName = zone?.name, zoneName.isEmpty == false {
            return zoneName
        }
        if let id = resource?.id, id.isEmpty == false {
            return id.middleEllipsizedToken
        }
        if let zoneID = zone?.id, zoneID.isEmpty == false {
            return zoneID.middleEllipsizedToken
        }
        return "Resource Unavailable"
    }

    var interfaceTitle: String? {
        guard let interface, interface.isEmpty == false else { return nil }
        return interface.replacingOccurrences(of: "_", with: " ").localizedCapitalized
    }

    var resultTint: Color {
        switch action?.result?.lowercased() {
        case "success", "ok", "allowed":
            .green
        case "failure", "failed", "error", "blocked":
            .red
        default:
            .orange
        }
    }
}

nonisolated struct AuditLogAction: Hashable, Decodable, Sendable {
    let type: String?
    let result: String?
}

nonisolated struct AuditLogActor: Hashable, Decodable, Sendable {
    let id: String?
    let email: String?
    let ip: String?
}

nonisolated struct AuditLogResource: Hashable, Decodable, Sendable {
    let id: String?
    let type: String?
    let name: String?
}

nonisolated struct AuditLogZone: Hashable, Decodable, Sendable {
    let id: String?
    let name: String?
}
