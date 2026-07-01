import Foundation
import Observation

@MainActor
@Observable
final class KVViewModel {
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

    var kvNamespaces: [KVNamespace] {
        accountStore.kvNamespaces
    }

    var kvStatusMessage: String? {
        accountStore.kvStatusMessage
    }

    var isRefreshingKV: Bool {
        loadingStore.isRefreshingKV
    }

    func isLoaded(for accountID: String) -> Bool {
        context.isAccountDataProductLoaded(.kv, for: accountID)
    }

    func refreshKVCatalog(force: Bool = false) async {
        guard let accountContext = context.validateAccountContext() else {
            accountStore.clearProduct(.kv, statusMessage: context.invalidAccountContextMessage())
            return
        }

        let accountID = accountContext.accountID
        guard force || isLoaded(for: accountID) == false else { return }
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        await context.withLoadingActivity(.kv) {
            let didRefresh = await refreshKVNamespaces(accountID: accountID)
            guard didRefresh, context.isCurrent(requestContext) else { return }
            context.markAccountDataProductLoaded(.kv, accountID: accountID)
        }
    }

    func loadKVNamespaceDetail(namespaceID: String) async throws -> KVNamespace {
        let accountID = try context.requireAccountID("This token cannot access account-level KV data.")
        return try await context.api.fetchKVNamespace(accountID: accountID, namespaceID: namespaceID)
    }

    func loadKVNamespaceKeys(namespaceID: String, cursor: String? = nil) async throws -> KVNamespaceKeyPage {
        let accountID = try context.requireAccountID("This token cannot access account-level KV data.")
        return try await context.api.listKVNamespaceKeys(
            accountID: accountID,
            namespaceID: namespaceID,
            cursor: cursor
        )
    }

    func loadKVValue(namespaceID: String, keyName: String) async throws -> KVValueSnapshot {
        let accountID = try context.requireAccountID("This token cannot access account-level KV data.")
        return try await context.api.fetchKVValue(
            accountID: accountID,
            namespaceID: namespaceID,
            keyName: keyName
        )
    }

    func writeKVValue(
        namespaceID: String,
        keyName: String,
        value: String,
        metadata: JSONValue?,
        expiration: Date?,
        expirationTTL: Int?
    ) async throws {
        let accountID = try context.requireAccountID("This token cannot access account-level KV data.")
        try await context.api.writeKVValue(
            accountID: accountID,
            namespaceID: namespaceID,
            keyName: keyName,
            value: value,
            metadata: metadata,
            expiration: expiration,
            expirationTTL: expirationTTL
        )
    }

    func deleteKVValue(namespaceID: String, keyName: String) async throws {
        let accountID = try context.requireAccountID("This token cannot access account-level KV data.")
        try await context.api.deleteKVValue(
            accountID: accountID,
            namespaceID: namespaceID,
            keyName: keyName
        )
    }

    func bulkWriteKVValues(namespaceID: String, entries: [KVBulkWriteEntry]) async throws -> KVBulkMutationResult {
        let accountID = try context.requireAccountID("This token cannot access account-level KV data.")
        return try await context.api.bulkWriteKVValues(
            accountID: accountID,
            namespaceID: namespaceID,
            entries: entries
        )
    }

    func bulkDeleteKVValues(namespaceID: String, keys: [String]) async throws -> KVBulkMutationResult {
        let accountID = try context.requireAccountID("This token cannot access account-level KV data.")
        return try await context.api.bulkDeleteKVValues(
            accountID: accountID,
            namespaceID: namespaceID,
            keys: keys
        )
    }

    @discardableResult
    private func refreshKVNamespaces(accountID: String) async -> Bool {
        let requestContext = context.makeAccountRequestContext(accountID: accountID)

        do {
            let namespaces = try await context.api.listKVNamespaces(accountID: accountID)

            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale KV catalog response.")
                return false
            }

            accountStore.kvNamespaces = namespaces.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            accountStore.kvStatusMessage = namespaces.isEmpty ? "No KV namespaces found." : nil
            return true
        } catch {
            guard context.isCurrent(requestContext) else {
                context.logDebug("Discarded stale KV catalog error.")
                return false
            }

            accountStore.kvNamespaces = []
            accountStore.kvStatusMessage = error.localizedDescription
            return false
        }
    }
}
