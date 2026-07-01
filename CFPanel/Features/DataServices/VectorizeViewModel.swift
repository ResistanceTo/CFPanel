import Foundation
import Observation

@MainActor
@Observable
final class VectorizeViewModel {
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

    var vectorizeIndexes: [VectorizeIndex] {
        accountStore.vectorizeIndexes
    }

    var vectorizeStatusMessage: String? {
        accountStore.vectorizeStatusMessage
    }

    var isRefreshingVectorize: Bool {
        loadingStore.isRefreshingVectorize
    }

    func isLoaded(for accountID: String) -> Bool {
        context.isAccountDataProductLoaded(.vectorize, for: accountID)
    }

    func refreshVectorizeCatalog(force: Bool = false) async {
        guard let accountContext = context.validateAccountContext() else {
            accountStore.clearProduct(.vectorize, statusMessage: context.invalidAccountContextMessage())
            return
        }

        let accountID = accountContext.accountID
        guard force || isLoaded(for: accountID) == false else { return }
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        await context.withLoadingActivity(.vectorize) {
            let didRefresh = await refreshVectorizeIndexes(accountID: accountID)
            guard didRefresh, context.isCurrent(requestContext) else { return }
            context.markAccountDataProductLoaded(.vectorize, accountID: accountID)
        }
    }

    func loadVectorizeIndexDetail(indexName: String) async throws -> VectorizeIndex {
        let accountID = try context.requireAccountID("This token cannot access account-level Vectorize data.")
        return try await context.api.fetchVectorizeIndex(accountID: accountID, indexName: indexName)
    }

    func loadVectorizeMetadataIndexes(indexName: String) async throws -> [VectorizeMetadataIndex] {
        let accountID = try context.requireAccountID("This token cannot access account-level Vectorize metadata index data.")
        return try await context.api.listVectorizeMetadataIndexes(accountID: accountID, indexName: indexName)
    }

    @discardableResult
    private func refreshVectorizeIndexes(accountID: String) async -> Bool {
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        do {
            let indexes = try await context.api.listVectorizeIndexes(accountID: accountID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Vectorize catalog response.")
                return false
            }

            accountStore.vectorizeIndexes = indexes.sorted {
                if $0.modifiedOn == $1.modifiedOn {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return ($0.modifiedOn ?? $0.createdOn ?? .distantPast) > ($1.modifiedOn ?? $1.createdOn ?? .distantPast)
            }
            accountStore.vectorizeStatusMessage = indexes.isEmpty ? "No Vectorize indexes found." : nil
            return true
        } catch {
            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale Vectorize catalog error.")
                return false
            }

            accountStore.vectorizeIndexes = []
            accountStore.vectorizeStatusMessage = error.localizedDescription
            return false
        }
    }
}
