import Foundation
import Observation

@MainActor
@Observable
final class QueuesViewModel {
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

    var queues: [QueueSummary] {
        accountStore.queues
    }

    var queuesStatusMessage: String? {
        accountStore.queuesStatusMessage
    }

    var isRefreshingQueues: Bool {
        loadingStore.isRefreshingQueues
    }

    func isLoaded(for accountID: String) -> Bool {
        context.isAccountDataProductLoaded(.queues, for: accountID)
    }

    func refreshQueuesCatalog(force: Bool = false) async {
        guard let accountContext = context.validateAccountContext() else {
            accountStore.clearProduct(.queues, statusMessage: context.invalidAccountContextMessage())
            return
        }

        let accountID = accountContext.accountID
        guard force || isLoaded(for: accountID) == false else { return }
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        await context.withLoadingActivity(.queues) {
            let didRefresh = await refreshQueues(accountID: accountID)
            guard didRefresh, context.isCurrent(requestContext) else { return }
            context.markAccountDataProductLoaded(.queues, accountID: accountID)
        }
    }

    func loadQueueDetail(queueID: String) async throws -> QueueDetail {
        let accountID = try context.requireAccountID("This token cannot access account-level Queues data.")
        return try await context.api.fetchQueue(accountID: accountID, queueID: queueID)
    }

    @discardableResult
    private func refreshQueues(accountID: String) async -> Bool {
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        do {
            let resolvedQueues = try await context.api.listQueues(accountID: accountID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Queues catalog response.")
                return false
            }

            accountStore.queues = resolvedQueues.sorted {
                if $0.modifiedOn == $1.modifiedOn {
                    return $0.queueName.localizedStandardCompare($1.queueName) == .orderedAscending
                }
                return ($0.modifiedOn ?? $0.createdOn ?? .distantPast) > ($1.modifiedOn ?? $1.createdOn ?? .distantPast)
            }
            accountStore.queuesStatusMessage = resolvedQueues.isEmpty ? "No Queues found." : nil
            return true
        } catch {
            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Queues catalog error.")
                return false
            }

            accountStore.queues = []
            accountStore.queuesStatusMessage = error.localizedDescription
            return false
        }
    }
}
