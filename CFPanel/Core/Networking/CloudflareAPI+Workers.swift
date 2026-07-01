import Foundation

extension CloudflareAPI {
    func listWorkerScripts(accountID: String) async throws -> [WorkerScript] {
        // Workers scripts API does not support pagination parameters
        let envelope: CloudflareEnvelope<[WorkerScript]> = try await requestEnvelope(
            path: "/accounts/\(accountID)/workers/scripts"
        )
        try validateEnvelope(envelope)
        return envelope.result ?? []
    }

    func listWorkerDeployments(accountID: String, scriptName: String) async throws -> [WorkerDeployment] {
        let encodedName = try encodedPathComponent(scriptName)
        let response: WorkerDeploymentList = try await request(
            path: "/accounts/\(accountID)/workers/scripts/\(encodedName)/deployments"
        )
        return response.deployments
    }

    func listWorkerVersions(accountID: String, scriptName: String) async throws -> [WorkerVersion] {
        let encodedName = try encodedPathComponent(scriptName)
        return try await requestAllPages(
            path: "/accounts/\(accountID)/workers/scripts/\(encodedName)/versions",
            extractItems: { (response: WorkerVersionListResult) in response.items ?? [] }
        )
    }

    func fetchWorkerVersion(
        accountID: String,
        scriptName: String,
        versionID: String
    ) async throws -> WorkerVersionDetail {
        let encodedName = try encodedPathComponent(scriptName)
        return try await request(
            path: "/accounts/\(accountID)/workers/scripts/\(encodedName)/versions/\(versionID)"
        )
    }

    func fetchWorkerSubdomain(accountID: String, scriptName: String) async throws -> WorkerSubdomainStatus {
        let encodedName = try encodedPathComponent(scriptName)
        return try await request(path: "/accounts/\(accountID)/workers/scripts/\(encodedName)/subdomain")
    }

    func updateWorkerSubdomain(
        accountID: String,
        scriptName: String,
        enabled: Bool,
        previewsEnabled: Bool
    ) async throws -> WorkerSubdomainStatus {
        let encodedName = try encodedPathComponent(scriptName)
        return try await request(
            path: "/accounts/\(accountID)/workers/scripts/\(encodedName)/subdomain",
            method: "POST",
            body: WorkerSubdomainUpdateRequest(enabled: enabled, previewsEnabled: previewsEnabled)
        )
    }

    func deleteWorkerSubdomain(accountID: String, scriptName: String) async throws {
        let encodedName = try encodedPathComponent(scriptName)
        try await requestWithoutResult(
            path: "/accounts/\(accountID)/workers/scripts/\(encodedName)/subdomain",
            method: "DELETE"
        )
    }

    func fetchAccountWorkersSubdomain(accountID: String) async throws -> AccountWorkersSubdomain {
        try await request(path: "/accounts/\(accountID)/workers/subdomain")
    }

    func fetchWorkerSchedules(accountID: String, scriptName: String) async throws -> [WorkerCronSchedule] {
        let encodedName = try encodedPathComponent(scriptName)
        let response: WorkerScheduleListResponse = try await request(
            path: "/accounts/\(accountID)/workers/scripts/\(encodedName)/schedules"
        )
        return response.schedules
    }

    func fetchWorkerScriptSettings(accountID: String, scriptName: String) async throws -> WorkerScriptSettings {
        let encodedName = try encodedPathComponent(scriptName)
        return try await request(
            path: "/accounts/\(accountID)/workers/scripts/\(encodedName)/settings"
        )
    }

    func listWorkerRoutes(zoneID: String) async throws -> [WorkerRoute] {
        try await requestAllPages(path: "/zones/\(zoneID)/workers/routes")
    }

    func createWorkerRoute(zoneID: String, pattern: String, scriptName: String) async throws -> WorkerRoute {
        try await request(
            path: "/zones/\(zoneID)/workers/routes",
            method: "POST",
            body: WorkerRouteMutationRequest(pattern: pattern, script: scriptName)
        )
    }

    func updateWorkerRoute(
        zoneID: String,
        routeID: String,
        pattern: String,
        scriptName: String
    ) async throws -> WorkerRoute {
        try await request(
            path: "/zones/\(zoneID)/workers/routes/\(routeID)",
            method: "PUT",
            body: WorkerRouteMutationRequest(pattern: pattern, script: scriptName)
        )
    }

    func deleteWorkerRoute(zoneID: String, routeID: String) async throws {
        try await requestWithoutResult(
            path: "/zones/\(zoneID)/workers/routes/\(routeID)",
            method: "DELETE"
        )
    }

    func listWorkerDomains(
        accountID: String,
        service: String,
        zoneID: String?
    ) async throws -> [WorkerDomain] {
        var queryItems = [URLQueryItem(name: "service", value: service)]
        if let zoneID, zoneID.isEmpty == false {
            queryItems.append(URLQueryItem(name: "zone_id", value: zoneID))
        }
        return try await requestAllPages(
            path: "/accounts/\(accountID)/workers/domains",
            queryItems: queryItems
        )
    }

    func attachWorkerDomain(
        accountID: String,
        hostname: String,
        service: String,
        zoneID: String
    ) async throws -> WorkerDomain {
        try await request(
            path: "/accounts/\(accountID)/workers/domains",
            method: "PUT",
            body: WorkerCustomDomainUpdateRequest(
                hostname: hostname,
                service: service,
                zoneID: zoneID
            )
        )
    }

    func deleteWorkerDomain(accountID: String, domainID: String) async throws {
        try await requestWithoutResult(
            path: "/accounts/\(accountID)/workers/domains/\(domainID)",
            method: "DELETE"
        )
    }
}
