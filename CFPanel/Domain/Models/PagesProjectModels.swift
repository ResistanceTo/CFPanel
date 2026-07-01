import Foundation

nonisolated struct PagesProject: Identifiable, Decodable, Sendable {
    let id: String
    let name: String
    let subdomain: String?
    let productionBranch: String?
    let createdOn: Date?
    let canonicalDeployment: PagesDeployment?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subdomain
        case productionBranch = "production_branch"
        case createdOn = "created_on"
        case canonicalDeployment = "canonical_deployment"
    }

    var latestStatusText: String {
        canonicalDeployment?.latestStage?.displayText ?? "No production deployment"
    }

    var lastDeploymentDate: Date? {
        canonicalDeployment?.modifiedOn ?? canonicalDeployment?.createdOn
    }

    var hasProductionDeployment: Bool {
        canonicalDeployment != nil
    }

    var deploymentRecencyText: String? {
        guard let lastDeploymentDate else { return nil }
        return lastDeploymentDate.formatted(.relative(presentation: .named))
    }

    var isDeploymentHealthy: Bool {
        canonicalDeployment?.latestStage?.isHealthy ?? false
    }

    var isDeploymentInProgress: Bool {
        canonicalDeployment?.latestStage?.isInProgress ?? false
    }

    var isDeploymentFailing: Bool {
        canonicalDeployment?.latestStage?.isFailure ?? false
    }

    var deploymentBadgeText: String {
        if hasProductionDeployment == false {
            return "Missing"
        }
        if isDeploymentFailing {
            return "Failed"
        }
        if isDeploymentInProgress {
            return "Building"
        }
        if isDeploymentHealthy {
            return "Live"
        }
        return "Unknown"
    }
}

nonisolated struct PagesDeployment: Identifiable, Decodable, Sendable {
    let id: String
    let url: String?
    let aliases: [String]?
    let environment: String?
    let shortID: String?
    let createdOn: Date?
    let modifiedOn: Date?
    let latestStage: PagesDeploymentStage?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case aliases
        case environment
        case shortID = "short_id"
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case latestStage = "latest_stage"
    }

    var health: PagesDeploymentHealth {
        guard let latestStage else { return .unknown }
        if latestStage.isFailure {
            return .failed
        }
        if latestStage.isInProgress {
            return .inProgress
        }
        if latestStage.isHealthy {
            return .healthy
        }
        return .unknown
    }

    var statusTitle: String {
        latestStage?.displayText ?? "Unknown Status"
    }

    var environmentTitle: String {
        environment?.replacingOccurrences(of: "_", with: " ").localizedCapitalized ?? "Unknown"
    }

    var canRollback: Bool {
        environment?.lowercased() == "production" && health == .healthy
    }
}

nonisolated enum PagesDeploymentHealth: String, Sendable {
    case healthy
    case inProgress
    case failed
    case unknown
}

nonisolated struct PagesDeploymentStage: Decodable, Sendable {
    let name: String?
    let status: String?
    let startedOn: Date?
    let endedOn: Date?

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case startedOn = "started_on"
        case endedOn = "ended_on"
    }

    var displayText: String {
        let normalizedStatus = status?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Unknown"
        if let name, name.isEmpty == false {
            return "\(name.capitalized) • \(normalizedStatus)"
        }
        return normalizedStatus
    }

    var normalizedStatus: String {
        status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    var isHealthy: Bool {
        ["success", "active", "deployed", "complete", "completed"].contains(normalizedStatus)
    }

    var isInProgress: Bool {
        ["queued", "pending", "building", "initializing", "deploying", "running", "in_progress"]
            .contains(normalizedStatus)
    }

    var isFailure: Bool {
        ["failure", "failed", "error", "errored", "canceled", "cancelled"].contains(normalizedStatus)
    }
}

nonisolated enum PagesOperationalNoteSeverity: String, Sendable {
    case critical
    case warning
    case info
}

nonisolated struct PagesOperationalNote: Identifiable, Equatable, Sendable {
    let severity: PagesOperationalNoteSeverity
    let title: String
    let message: String

    var id: String { "\(severity.rawValue)-\(title)" }
}

nonisolated struct PagesEnvironmentSummary: Sendable {
    let title: String
    let deployments: [PagesDeployment]

    var latestDeployment: PagesDeployment? {
        deployments.first
    }

    var healthyCount: Int {
        deployments.filter { $0.health == .healthy }.count
    }

    var failedCount: Int {
        deployments.filter { $0.health == .failed }.count
    }

    var inProgressCount: Int {
        deployments.filter { $0.health == .inProgress }.count
    }

    var badgeText: String {
        guard let latestDeployment else { return "Missing" }

        switch latestDeployment.health {
        case .healthy:
            return "Healthy"
        case .inProgress:
            return "Building"
        case .failed:
            return "Failed"
        case .unknown:
            return "Unknown"
        }
    }

    var statusText: String {
        guard let latestDeployment else { return "No deployment history" }
        return latestDeployment.statusTitle
    }

    var updatedText: String? {
        guard let date = latestDeployment?.modifiedOn ?? latestDeployment?.createdOn else { return nil }
        return date.formatted(.relative(presentation: .named))
    }

    var operationalNotes: [PagesOperationalNote] {
        guard deployments.isEmpty == false else {
            return [
                PagesOperationalNote(
                    severity: .warning,
                    title: "No \(title.lowercased()) deployments",
                    message: "Cloudflare did not return any \(title.lowercased()) deployment history."
                )
            ]
        }

        var notes: [PagesOperationalNote] = []

        if let latestDeployment, latestDeployment.health == .failed {
            notes.append(
                PagesOperationalNote(
                    severity: .critical,
                    title: "\(title) deployment failed",
                    message: "The latest \(title.lowercased()) deployment is not healthy and needs attention."
                )
            )
        }

        if healthyCount == 0, failedCount > 0 {
            notes.append(
                PagesOperationalNote(
                    severity: .warning,
                    title: "No healthy \(title.lowercased()) deployment",
                    message: "Every visible \(title.lowercased()) deployment is either failed, building, or unknown."
                )
            )
        }

        if inProgressCount > 0 {
            notes.append(
                PagesOperationalNote(
                    severity: .info,
                    title: "\(title) deployment in progress",
                    message: "Cloudflare is still processing at least one \(title.lowercased()) deployment."
                )
            )
        }

        return notes
    }
}
