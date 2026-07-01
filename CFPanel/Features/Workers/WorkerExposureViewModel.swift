import Foundation
import Observation

@MainActor
@Observable
final class WorkerExposureViewModel {
    @ObservationIgnored
    private let context: AccountServicesContext

    init(context: AccountServicesContext) {
        self.context = context
    }

    var selectedZoneID: String? {
        context.selectedZoneID
    }

    var selectedZone: CloudflareZone? {
        context.selectedZone
    }

    func loadWorkerExposureManagement(scriptName: String) async throws -> WorkerExposureManagementSnapshot {
        let accountID = try context.requireAccountID("This token cannot access account-level Workers data.")

        async let subdomain = context.api.fetchWorkerSubdomain(accountID: accountID, scriptName: scriptName)
        async let accountSubdomainResult = context.partialResult {
            try await self.context.api.fetchAccountWorkersSubdomain(accountID: accountID)
        }
        async let domainsResult = context.partialResult {
            try await self.context.api.listWorkerDomains(
                accountID: accountID,
                service: scriptName,
                zoneID: self.selectedZoneID
            )
        }
        let routesResult: Result<[WorkerRoute], Error>?
        if let selectedZoneID {
            let result = await context.partialResult {
                try await self.context.api.listWorkerRoutes(zoneID: selectedZoneID)
            }
            routesResult = result.map { routes in
                routes.filter { $0.script == scriptName }
            }
        } else {
            routesResult = nil
        }

        let resolvedSubdomain = try await subdomain
        let resolvedAccountSubdomain = await accountSubdomainResult
        let resolvedDomains = await domainsResult

        return WorkerExposureManagementSnapshot(
            scriptName: scriptName,
            subdomainStatus: resolvedSubdomain,
            accountSubdomain: resolvedAccountSubdomain.value,
            accountSubdomainErrorMessage: resolvedAccountSubdomain.errorMessage,
            routes: routesResult?.value,
            routeErrorMessage: routesResult?.errorMessage,
            domains: resolvedDomains.value,
            domainErrorMessage: resolvedDomains.errorMessage
        )
    }

    func updateWorkerSubdomain(
        scriptName: String,
        enabled: Bool,
        previewsEnabled: Bool
    ) async throws -> WorkerSubdomainStatus {
        let accountID = try context.requireAccountID("This token cannot update workers.dev exposure for this script.")

        return try await context.api.updateWorkerSubdomain(
            accountID: accountID,
            scriptName: scriptName,
            enabled: enabled,
            previewsEnabled: previewsEnabled
        )
    }

    func deleteWorkerSubdomain(scriptName: String) async throws {
        let accountID = try context.requireAccountID("This token cannot delete workers.dev exposure for this script.")
        try await context.api.deleteWorkerSubdomain(accountID: accountID, scriptName: scriptName)
    }

    func createWorkerRoute(scriptName: String, pattern: String) async throws -> WorkerRoute {
        let zoneID = try context.requireSelectedZoneID("Select a zone before creating a Worker route.")
        return try await context.api.createWorkerRoute(zoneID: zoneID, pattern: pattern, scriptName: scriptName)
    }

    func updateWorkerRoute(routeID: String, scriptName: String, pattern: String) async throws -> WorkerRoute {
        let zoneID = try context.requireSelectedZoneID("Select a zone before updating a Worker route.")
        return try await context.api.updateWorkerRoute(
            zoneID: zoneID,
            routeID: routeID,
            pattern: pattern,
            scriptName: scriptName
        )
    }

    func deleteWorkerRoute(routeID: String) async throws {
        let zoneID = try context.requireSelectedZoneID("Select a zone before deleting a Worker route.")
        try await context.api.deleteWorkerRoute(zoneID: zoneID, routeID: routeID)
    }

    func attachWorkerCustomDomain(scriptName: String, hostname: String) async throws -> WorkerDomain {
        let accountID = try context.requireAccountID("This token cannot manage Worker custom domains.")
        let zoneID = try context.requireSelectedZoneID("Select a zone before attaching a Worker custom domain.")

        return try await context.api.attachWorkerDomain(
            accountID: accountID,
            hostname: hostname,
            service: scriptName,
            zoneID: zoneID
        )
    }

    func deleteWorkerCustomDomain(domainID: String) async throws {
        let accountID = try context.requireAccountID("This token cannot manage Worker custom domains.")
        try await context.api.deleteWorkerDomain(accountID: accountID, domainID: domainID)
    }
}
