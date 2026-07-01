import Foundation
import Observation

@MainActor
@Observable
final class WorkersCatalogViewModel {
    @ObservationIgnored
    private let accountStore: AccountServicesStore
    @ObservationIgnored
    private let loadingStore: LoadingStateStore
    @ObservationIgnored
    private let context: AccountServicesContext

    init(
        accountStore: AccountServicesStore,
        loadingStore: LoadingStateStore,
        context: AccountServicesContext
    ) {
        self.accountStore = accountStore
        self.loadingStore = loadingStore
        self.context = context
    }

    var resolvedAccountID: String? {
        context.resolvedAccountID
    }

    var workerRuntimes: [WorkerRuntimeSummary] {
        accountStore.workerRuntimes
    }

    var workersStatusMessage: String? {
        accountStore.workersStatusMessage
    }

    var workersUsage: WorkersUsageSnapshot? {
        accountStore.workersUsage
    }

    var workersUsageStatusMessage: String? {
        accountStore.workersUsageStatusMessage
    }

    var isRefreshingWorkers: Bool {
        loadingStore.isRefreshingWorkers
    }

    func workerRuntime(id: String) -> WorkerRuntimeSummary? {
        workerRuntimes.first { $0.id == id }
    }

    func isWorkersLoaded(for accountID: String) -> Bool {
        context.isWorkersLoaded(for: accountID)
    }

    func refreshWorkersCatalog(force: Bool = false) async {
        guard let accountContext = context.validateAccountContext() else {
            accountStore.clearWorkers(statusMessage: context.invalidAccountContextMessage())
            return
        }

        let accountID = accountContext.accountID
        guard force || isWorkersLoaded(for: accountID) == false else { return }
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        await context.withLoadingActivity(.workers) {
            let didRefresh = await refreshWorkerRuntimes(accountID: accountID)
            guard didRefresh, context.isCurrent(requestContext) else { return }
            context.markWorkersLoaded(accountID: accountID)
        }
    }

    @discardableResult
    private func refreshWorkerRuntimes(accountID: String) async -> Bool {
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        do {
            async let scriptsResponse = context.api.listWorkerScripts(accountID: accountID)
            async let usageResponse: Result<WorkersUsageSnapshot, Error> = context.partialResult {
                try await self.context.api.fetchWorkersUsage(accountID: accountID)
            }

            let scripts = try await scriptsResponse
                .sorted { ($0.modifiedOn ?? .distantPast) > ($1.modifiedOn ?? .distantPast) }
            let routeCountByScript: [String: Int]
            let routeStatusMessage: String?
            if let selectedZoneID = context.selectedZoneID {
                let routesResult: Result<[WorkerRoute], Error> = await context.partialResult {
                    try await self.context.api.listWorkerRoutes(zoneID: selectedZoneID)
                }
                if let routes = routesResult.value {
                    routeCountByScript = Dictionary(grouping: routes, by: { $0.script ?? "" })
                        .mapValues(\.count)
                    routeStatusMessage = nil
                } else {
                    routeCountByScript = [:]
                    routeStatusMessage = routesResult.errorMessage.map {
                        "Loaded scripts, but route counts are unavailable: \(friendlyWorkersSupplementalMessage(for: routesResult.failureValue) ?? $0)"
                    }
                }
            } else {
                routeCountByScript = [:]
                routeStatusMessage = nil
            }

            let usageResult = await usageResponse
            let summaries = scripts.map { script in
                WorkerRuntimeSummary(
                    script: script,
                    latestDeployment: nil,
                    routeCount: routeCountByScript[script.id],
                    customDomainCount: nil,
                    scheduleCount: nil,
                    latestVersion: nil,
                    workersDevEnabled: nil,
                    previewsEnabled: nil
                )
            }

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Workers catalog response.")
                return false
            }

            accountStore.workerRuntimes = summaries
            accountStore.workersStatusMessage = summaries.isEmpty ? "No Workers scripts found." : routeStatusMessage
            accountStore.workersUsage = usageResult.value
            accountStore.workersUsageStatusMessage = usageResult.failureValue.flatMap(friendlyWorkersUsageMessage(for:))
            return true
        } catch {
            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Workers catalog error.")
                return false
            }

            accountStore.workerRuntimes = []
            accountStore.workersUsage = nil
            let statusMessage = friendlyWorkersStatusMessage(for: error)
            accountStore.workersStatusMessage = statusMessage
            accountStore.workersUsageStatusMessage = statusMessage
            return false
        }
    }

    private func friendlyWorkersStatusMessage(for error: Error) -> String {
        if let message = friendlyWorkersPermissionMessage(for: error) {
            return message
        }

        return "Workers data is currently unavailable for this account."
    }

    private func friendlyWorkersUsageMessage(for error: Error) -> String? {
        if isSilentCancellationError(error) {
            return nil
        }

        if let message = friendlyWorkersPermissionMessage(for: error) {
            return message
        }

        return "Workers usage metrics are currently unavailable."
    }

    private func friendlyWorkersSupplementalMessage(for error: Error?) -> String? {
        guard let error else { return nil }
        if isSilentCancellationError(error) {
            return nil
        }
        return friendlyWorkersPermissionMessage(for: error)
    }

    private func friendlyWorkersPermissionMessage(for error: Error) -> String? {
        switch error {
        case CloudflareAPIError.unauthorized:
            return "Workers data is unavailable. Verify that this token has account-level Workers read access."
        case CloudflareAPIError.httpStatus(let code, let message):
            guard code == 403 || code == 404 else { return nil }
            if message.localizedCaseInsensitiveContains("authentication error")
                || message.localizedCaseInsensitiveContains("unable to authenticate request")
            {
                return "Workers data is unavailable. Verify that this token has account-level Workers read access."
            }
            return "Workers data is unavailable for this account."
        case CloudflareAPIError.graphQL(let message):
            if message.localizedCaseInsensitiveContains("authentication")
                || message.localizedCaseInsensitiveContains("permission")
            {
                return "Workers usage metrics are unavailable. Verify that this token can access Workers analytics for the current account."
            }
            return nil
        case CloudflareAPIError.api(let message):
            if message.localizedCaseInsensitiveContains("workers")
                && message.localizedCaseInsensitiveContains("account-level")
            {
                return message
            }
            return nil
        default:
            return nil
        }
    }
}

private func isSilentCancellationError(_ error: Error) -> Bool {
    if error is CancellationError {
        return true
    }

    if let urlError = error as? URLError,
       urlError.code == .cancelled
    {
        return true
    }

    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue
}

private extension Result where Failure == Error {
    var failureValue: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}
