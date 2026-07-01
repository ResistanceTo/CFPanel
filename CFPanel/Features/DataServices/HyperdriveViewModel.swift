import Foundation
import Observation

@MainActor
@Observable
final class HyperdriveViewModel {
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

    var hyperdriveConfigs: [HyperdriveConfig] {
        accountStore.hyperdriveConfigs
    }

    var hyperdriveStatusMessage: String? {
        accountStore.hyperdriveStatusMessage
    }

    var isRefreshingHyperdrive: Bool {
        loadingStore.isRefreshingHyperdrive
    }

    func isLoaded(for accountID: String) -> Bool {
        context.isAccountDataProductLoaded(.hyperdrive, for: accountID)
    }

    func refreshHyperdriveCatalog(force: Bool = false) async {
        guard let accountContext = context.validateAccountContext() else {
            accountStore.clearProduct(.hyperdrive, statusMessage: context.invalidAccountContextMessage())
            return
        }

        let accountID = accountContext.accountID
        guard force || isLoaded(for: accountID) == false else { return }
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        await context.withLoadingActivity(.hyperdrive) {
            let didRefresh = await refreshHyperdriveConfigs(accountID: accountID)
            guard didRefresh, context.isCurrent(requestContext) else { return }
            context.markAccountDataProductLoaded(.hyperdrive, accountID: accountID)
        }
    }

    func loadHyperdriveConfigDetail(configID: String) async throws -> HyperdriveConfig {
        let accountID = try context.requireAccountID("This token cannot access account-level Hyperdrive data.")
        return try await context.api.fetchHyperdriveConfig(accountID: accountID, configID: configID)
    }

    @discardableResult
    private func refreshHyperdriveConfigs(accountID: String) async -> Bool {
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        do {
            let configs = try await context.api.listHyperdriveConfigs(accountID: accountID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Hyperdrive catalog response.")
                return false
            }

            accountStore.hyperdriveConfigs = configs.sorted {
                if $0.modifiedOn == $1.modifiedOn {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return ($0.modifiedOn ?? $0.createdOn ?? .distantPast) > ($1.modifiedOn ?? $1.createdOn ?? .distantPast)
            }
            accountStore.hyperdriveStatusMessage = configs.isEmpty ? "No Hyperdrive configurations found." : nil
            return true
        } catch {
            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Hyperdrive catalog error.")
                return false
            }

            accountStore.hyperdriveConfigs = []
            accountStore.hyperdriveStatusMessage = error.localizedDescription
            return false
        }
    }
}
