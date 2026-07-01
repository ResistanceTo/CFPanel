import Foundation

nonisolated struct WorkerRuntimeSummary: Identifiable, Sendable {
    let script: WorkerScript
    let latestDeployment: WorkerDeployment?
    let routeCount: Int?
    let customDomainCount: Int?
    let scheduleCount: Int?
    let latestVersion: WorkerVersion?
    let workersDevEnabled: Bool?
    let previewsEnabled: Bool?

    var id: String { script.id }

    var runtimeText: String {
        if let latestDeployment {
            return "Latest deployment \(latestDeployment.createdOn?.formatted(date: .abbreviated, time: .shortened) ?? "unknown")"
        }
        if let latestVersion {
            return "Latest version \(latestVersion.versionNumberTitle)"
        }
        if let modifiedOn = script.modifiedOn ?? script.createdOn {
            return "Modified \(modifiedOn.formatted(date: .abbreviated, time: .shortened))"
        }
        return "No deployment metadata"
    }

    var hasDeployment: Bool {
        latestDeployment != nil
    }

    var lastActivityDate: Date? {
        latestDeployment?.createdOn ?? script.modifiedOn ?? script.createdOn
    }

    var activityRecencyText: String? {
        guard let lastActivityDate else { return nil }
        return lastActivityDate.formatted(.relative(presentation: .named))
    }

    var hasPublicEndpoint: Bool {
        let routeActive = (routeCount ?? 0) > 0
        let domainActive = (customDomainCount ?? 0) > 0
        let devActive = workersDevEnabled == true
        return routeActive || domainActive || devActive
    }

    var hasScheduledInvocation: Bool {
        (scheduleCount ?? 0) > 0
    }

    var hasInvocationPath: Bool {
        hasPublicEndpoint || hasScheduledInvocation
    }

    var endpointSummaryText: String {
        var parts: [String] = []

        if let routeCount {
            parts.append(routeCount == 1 ? "1 route" : "\(routeCount) routes")
        }

        if let customDomainCount {
            parts.append(customDomainCount == 1 ? "1 domain" : "\(customDomainCount) domains")
        }

        if let workersDevEnabled {
            parts.append(workersDevEnabled ? "workers.dev on" : "workers.dev off")
        }

        if let scheduleCount {
            parts.append(scheduleCount == 1 ? "1 cron" : "\(scheduleCount) cron")
        }

        if let previewsEnabled, workersDevEnabled == true {
            parts.append(previewsEnabled ? "previews on" : "previews off")
        }

        return parts.isEmpty ? "Endpoint status unavailable" : parts.joined(separator: "  ·  ")
    }

    var endpointBadgeText: String {
        if hasPublicEndpoint {
            return "Reachable"
        }
        if hasScheduledInvocation {
            return "Scheduled"
        }
        return "Detached"
    }
}

nonisolated struct WorkerSubdomainStatus: Decodable, Sendable, Equatable {
    let enabled: Bool
    let previewsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case enabled
        case previewsEnabled = "previews_enabled"
    }
}

nonisolated struct AccountWorkersSubdomain: Decodable, Sendable, Equatable {
    let subdomain: String
}

nonisolated struct WorkerReleaseSnapshot: Sendable {
    let deployments: [WorkerDeployment]
    let deploymentErrorMessage: String?
    let versions: [WorkerVersion]
    let versionErrorMessage: String?

    var resolvedDeployments: [WorkerDeployment] {
        deployments.sorted {
            ($0.createdOn ?? .distantPast) > ($1.createdOn ?? .distantPast)
        }
    }

    var resolvedVersions: [WorkerVersion] {
        versions.sorted {
            if $0.number == $1.number {
                return $0.id < $1.id
            }
            return ($0.number ?? -1) > ($1.number ?? -1)
        }
    }

    var operationalNotes: [WorkerOperationalNote] {
        var notes: [WorkerOperationalNote] = []

        if let deploymentErrorMessage {
            notes.append(
                WorkerOperationalNote(
                    severity: .warning,
                    title: "Deployment history partially unavailable",
                    message: deploymentErrorMessage
                )
            )
        }

        if deployments.isEmpty {
            notes.append(
                WorkerOperationalNote(
                    severity: .warning,
                    title: "No deployment history",
                    message: "Cloudflare did not return deployment metadata for this script."
                )
            )
        }

        if let versionErrorMessage {
            notes.append(
                WorkerOperationalNote(
                    severity: .warning,
                    title: "Version history partially unavailable",
                    message: versionErrorMessage
                )
            )
        }

        if versions.isEmpty {
            notes.append(
                WorkerOperationalNote(
                    severity: .info,
                    title: "No version history",
                    message: "Cloudflare did not return version metadata for this script."
                )
            )
        }

        return notes
    }
}

nonisolated struct WorkerRuntimeConfigurationSnapshot: Sendable {
    let settings: WorkerScriptSettings?
    let settingsErrorMessage: String?
    let schedules: [WorkerCronSchedule]?
    let scheduleErrorMessage: String?

    var resolvedSchedules: [WorkerCronSchedule] {
        (schedules ?? []).sorted {
            $0.cron.localizedStandardCompare($1.cron) == .orderedAscending
        }
    }

    var scheduleAvailabilityKnown: Bool {
        schedules != nil
    }

    var settingsAvailabilityKnown: Bool {
        settings != nil
    }

    var operationalNotes: [WorkerOperationalNote] {
        var notes: [WorkerOperationalNote] = []

        if let settingsErrorMessage {
            notes.append(
                WorkerOperationalNote(
                    severity: .warning,
                    title: "Runtime config visibility limited",
                    message: settingsErrorMessage
                )
            )
        }

        if let scheduleErrorMessage {
            notes.append(
                WorkerOperationalNote(
                    severity: .warning,
                    title: "Cron visibility limited",
                    message: scheduleErrorMessage
                )
            )
        } else if resolvedSchedules.isEmpty {
            notes.append(
                WorkerOperationalNote(
                    severity: .info,
                    title: "No cron triggers",
                    message: "Cloudflare did not return any cron schedules for this script."
                )
            )
        }

        return notes
    }
}
