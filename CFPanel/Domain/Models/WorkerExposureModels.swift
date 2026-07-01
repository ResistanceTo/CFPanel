import Foundation

nonisolated struct WorkerCronSchedule: Identifiable, Decodable, Sendable {
    let cron: String

    var id: String { cron }
}

nonisolated struct WorkerScheduleListResponse: Decodable, Sendable {
    let schedules: [WorkerCronSchedule]
}

nonisolated enum WorkerOperationalNoteSeverity: String, Sendable {
    case critical
    case warning
    case info
}

nonisolated struct WorkerOperationalNote: Identifiable, Equatable, Sendable {
    let severity: WorkerOperationalNoteSeverity
    let title: String
    let message: String

    var id: String { "\(severity.rawValue)-\(title)" }
}

nonisolated struct WorkerRoute: Identifiable, Decodable, Sendable {
    let id: String
    let pattern: String
    let script: String?
}

nonisolated struct WorkerRouteMutationRequest: Encodable, Sendable {
    let pattern: String
    let script: String
}

nonisolated struct WorkerSubdomainUpdateRequest: Encodable, Sendable {
    let enabled: Bool
    let previewsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case enabled
        case previewsEnabled = "previews_enabled"
    }
}

nonisolated struct WorkerCustomDomainUpdateRequest: Encodable, Sendable {
    let hostname: String
    let service: String
    let zoneID: String

    enum CodingKeys: String, CodingKey {
        case hostname
        case service
        case zoneID = "zone_id"
    }
}

nonisolated struct WorkerDomain: Identifiable, Decodable, Sendable {
    let id: String?
    let hostname: String?
    let service: String?
    let zoneID: String?
    let zoneName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case hostname
        case service
        case zoneID = "zone_id"
        case zoneName = "zone_name"
    }

    var listID: String {
        if let id, id.isEmpty == false {
            return id
        }

        return [hostname, service, zoneID, zoneName]
            .compactMap { value in
                guard let value, value.isEmpty == false else { return nil }
                return value
            }
            .joined(separator: "|")
    }
}

nonisolated struct WorkerExposureManagementSnapshot: Sendable {
    let scriptName: String
    let subdomainStatus: WorkerSubdomainStatus
    let accountSubdomain: AccountWorkersSubdomain?
    let accountSubdomainErrorMessage: String?
    let routes: [WorkerRoute]?
    let routeErrorMessage: String?
    let domains: [WorkerDomain]?
    let domainErrorMessage: String?

    var workersDevURL: String? {
        guard let accountSubdomain else { return nil }
        return "\(scriptName).\(accountSubdomain.subdomain).workers.dev"
    }

    var routeAvailabilityKnown: Bool {
        routes != nil
    }

    var resolvedRoutes: [WorkerRoute] {
        (routes ?? []).sorted { lhs, rhs in
            lhs.pattern.localizedStandardCompare(rhs.pattern) == .orderedAscending
        }
    }

    var domainAvailabilityKnown: Bool {
        domains != nil
    }

    var resolvedDomains: [WorkerDomain] {
        (domains ?? []).sorted {
            ($0.hostname ?? "").localizedStandardCompare($1.hostname ?? "") == .orderedAscending
        }
    }

    var operationalNotes: [WorkerOperationalNote] {
        var notes: [WorkerOperationalNote] = []

        if let accountSubdomainErrorMessage {
            notes.append(
                WorkerOperationalNote(
                    severity: .info,
                    title: "workers.dev hostname unavailable",
                    message: accountSubdomainErrorMessage
                )
            )
        }

        if let routeErrorMessage {
            notes.append(
                WorkerOperationalNote(
                    severity: .warning,
                    title: "Route visibility limited",
                    message: routeErrorMessage
                )
            )
        }

        if let domainErrorMessage {
            notes.append(
                WorkerOperationalNote(
                    severity: .warning,
                    title: "Custom domain visibility limited",
                    message: domainErrorMessage
                )
            )
        }

        if subdomainStatus.enabled, subdomainStatus.previewsEnabled == false {
            notes.append(
                WorkerOperationalNote(
                    severity: .info,
                    title: "Preview URLs disabled",
                    message: "Preview builds cannot be opened through workers.dev preview URLs."
                )
            )
        }

        return notes
    }
}
