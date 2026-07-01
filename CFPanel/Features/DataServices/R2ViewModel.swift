import Foundation
import Observation

@MainActor
@Observable
final class R2ViewModel {
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

    var r2Buckets: [R2Bucket] {
        accountStore.r2Buckets
    }

    var r2StatusMessage: String? {
        accountStore.r2StatusMessage
    }

    var isRefreshingR2: Bool {
        loadingStore.isRefreshingR2
    }

    func isLoaded(for accountID: String) -> Bool {
        context.isAccountDataProductLoaded(.r2, for: accountID)
    }

    func refreshR2Catalog(force: Bool = false) async {
        guard let accountContext = context.validateAccountContext() else {
            accountStore.clearProduct(.r2, statusMessage: context.invalidAccountContextMessage())
            return
        }

        let accountID = accountContext.accountID
        guard force || isLoaded(for: accountID) == false else { return }
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        await context.withLoadingActivity(.r2) {
            let didRefresh = await refreshR2Buckets(accountID: accountID)
            guard didRefresh, context.isCurrent(requestContext) else { return }
            context.markAccountDataProductLoaded(.r2, accountID: accountID)
        }
    }

    func loadR2BucketDetail(bucketName: String) async throws -> R2BucketDetail {
        let accountID = try context.requireAccountID("This token cannot access account-level R2 data.")
        return try await context.api.fetchR2Bucket(accountID: accountID, bucketName: bucketName)
    }

    @discardableResult
    private func refreshR2Buckets(accountID: String) async -> Bool {
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        do {
            let buckets = try await context.api.listR2Buckets(accountID: accountID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale R2 catalog response.")
                return false
            }

            accountStore.r2Buckets = buckets.sorted {
                if $0.creationDate == $1.creationDate {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
            }
            accountStore.r2StatusMessage = buckets.isEmpty ? "No R2 buckets found." : nil
            return true
        } catch {
            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale R2 catalog error.")
                return false
            }

            accountStore.r2Buckets = []
            accountStore.r2StatusMessage = error.localizedDescription
            return false
        }
    }
}
