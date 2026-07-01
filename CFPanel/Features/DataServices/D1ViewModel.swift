import Foundation
import Observation

@MainActor
@Observable
final class D1ViewModel {
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

    var d1Databases: [D1Database] {
        accountStore.d1Databases
    }

    var d1StatusMessage: String? {
        accountStore.d1StatusMessage
    }

    var isRefreshingD1: Bool {
        loadingStore.isRefreshingD1
    }

    func isLoaded(for accountID: String) -> Bool {
        context.isAccountDataProductLoaded(.d1, for: accountID)
    }

    func refreshD1Catalog(force: Bool = false) async {
        guard let accountContext = context.validateAccountContext() else {
            accountStore.clearProduct(.d1, statusMessage: context.invalidAccountContextMessage())
            return
        }

        let accountID = accountContext.accountID
        guard force || isLoaded(for: accountID) == false else { return }
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        await context.withLoadingActivity(.d1) {
            let didRefresh = await refreshD1Databases(accountID: accountID)
            guard didRefresh, context.isCurrent(requestContext) else { return }
            context.markAccountDataProductLoaded(.d1, accountID: accountID)
        }
    }

    func loadD1DatabaseDetail(databaseID: String) async throws -> D1DatabaseDetail {
        let accountID = try context.requireAccountID("This token cannot access account-level D1 data.")
        return try await context.api.fetchD1Database(accountID: accountID, databaseID: databaseID)
    }

    @discardableResult
    private func refreshD1Databases(accountID: String) async -> Bool {
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        do {
            let databases = try await context.api.listD1Databases(accountID: accountID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale D1 catalog response.")
                return false
            }

            accountStore.d1Databases = databases.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
            accountStore.d1StatusMessage = databases.isEmpty ? "No D1 databases found." : nil
            return true
        } catch {
            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale D1 catalog error.")
                return false
            }

            accountStore.d1Databases = []
            accountStore.d1StatusMessage = error.localizedDescription
            return false
        }
    }
}
