import Foundation

@MainActor
final class AccountServicesContext {
    let api: CloudflareAPI

    private let sessionStore: AuthSessionStore
    private let zoneStore: ZoneWorkspaceStore
    private let loadingStore: LoadingStateStore
    private let loadStateStore: ResourceLoadStateStore
    private let shellActions: AppShellActions

    init(
        api: CloudflareAPI,
        sessionStore: AuthSessionStore,
        zoneStore: ZoneWorkspaceStore,
        loadingStore: LoadingStateStore,
        loadStateStore: ResourceLoadStateStore,
        shellActions: AppShellActions
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.zoneStore = zoneStore
        self.loadingStore = loadingStore
        self.loadStateStore = loadStateStore
        self.shellActions = shellActions
    }

    var resolvedAccountID: String? {
        resolvedAccountContext?.accountID
    }

    var selectedZoneID: String? {
        zoneStore.selectedZoneID
    }

    var selectedZone: CloudflareZone? {
        zoneStore.selectedZone
    }

    func isPagesLoaded(for accountID: String) -> Bool {
        loadStateStore.isAccountResourceLoaded(.pages, accountID: accountID)
    }

    func isWorkersLoaded(for accountID: String) -> Bool {
        loadStateStore.isAccountResourceLoaded(.workers, accountID: accountID)
    }

    func isAccountDataProductLoaded(_ product: AccountDataProduct, for accountID: String) -> Bool {
        loadStateStore.isAccountResourceLoaded(.product(product), accountID: accountID)
    }

    func requireAccountID(_ message: String) throws -> String {
        guard let context = validateAccountContext() else {
            throw CloudflareAPIError.api(
                TokenPermissionGuidance.accountCapabilityMessage(message, tokenMode: sessionStore.tokenMode)
            )
        }
        return context.accountID
    }

    func requireSelectedZoneID(_ message: String) throws -> String {
        guard let selectedZoneID else {
            throw CloudflareAPIError.api(message)
        }
        return selectedZoneID
    }

    func validateAccountContext() -> ResolvedAccountContext? {
        guard let context = resolvedAccountContext else {
            logDebug("No resolved account context is available for \(sessionStore.tokenMode.rawValue) token mode.")
            return nil
        }

        guard isLikelyCloudflareAccountID(context.accountID) else {
            logDebug("Rejected malformed account ID from \(context.source). Length: \(context.accountID.count).")
            return nil
        }

        return context
    }

    func invalidAccountContextMessage() -> String {
        TokenPermissionGuidance.accountContextMessage(tokenMode: .account)
    }

    func makeAccountRequestContext(accountID: String) -> AccountRequestContext {
        sessionStore.makeAccountRequestContext(accountID: accountID)
    }

    func isCurrent(_ context: AccountRequestContext) -> Bool {
        sessionStore.isCurrent(context, resolvedAccountID: resolvedAccountID)
    }

    func markPagesLoaded(accountID: String) {
        loadStateStore.markAccountResourceLoaded(.pages, accountID: accountID)
        zoneStore.lastRefreshAt = Date()
    }

    func markWorkersLoaded(accountID: String) {
        loadStateStore.markAccountResourceLoaded(.workers, accountID: accountID)
        zoneStore.lastRefreshAt = Date()
    }

    func markAccountDataProductLoaded(_ product: AccountDataProduct, accountID: String) {
        loadStateStore.markAccountResourceLoaded(.product(product), accountID: accountID)
        zoneStore.lastRefreshAt = Date()
    }

    func withLoadingActivity<T>(
        _ activity: LoadingActivity,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let count = loadingStore.begin(activity)
        logDebug("Started \(activity.rawValue) activity. Active count: \(count).")
        defer {
            let count = loadingStore.end(activity)
            logDebug("Finished \(activity.rawValue) activity. Active count: \(count).")
        }
        return try await operation()
    }

    func logDebug(_ message: String) {
        shellActions.logDebug(message)
    }

    func partialResult<T>(
        _ operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private var resolvedAccountContext: ResolvedAccountContext? {
        let normalizedInput = sessionStore.accountIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedInput.isEmpty == false else { return nil }
        return ResolvedAccountContext(accountID: normalizedInput, source: "account token input")
    }

    private func isLikelyCloudflareAccountID(_ value: String) -> Bool {
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return value.count == 32 && value.unicodeScalars.allSatisfy { hexCharacterSet.contains($0) }
    }
}

extension Result where Failure == Error {
    var value: Success? {
        switch self {
        case .success(let success):
            return success
        case .failure:
            return nil
        }
    }

    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error.localizedDescription
        }
    }
}
