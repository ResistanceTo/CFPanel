import Foundation

@MainActor
final class EmailWorkspaceContext {
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

    var selectedZoneID: String? {
        zoneStore.selectedZoneID
    }

    var selectedZone: CloudflareZone? {
        zoneStore.selectedZone
    }

    var tokenVerification: TokenVerification? {
        sessionStore.tokenVerification
    }

    var lastRefreshAt: Date? {
        zoneStore.lastRefreshAt
    }

    var resolvedAccountID: String? {
        resolvedAccountContext?.accountID
    }

    func requireSelectedZoneID(_ message: String) throws -> String {
        guard let selectedZoneID else {
            throw CloudflareAPIError.api(message)
        }
        return selectedZoneID
    }

    func requireAccountID(_ message: String) throws -> String {
        guard let accountID = resolvedAccountID else {
            throw CloudflareAPIError.api(
                TokenPermissionGuidance.accountCapabilityMessage(message, tokenMode: sessionStore.tokenMode)
            )
        }
        return accountID
    }

    func isEmailRoutingLoaded(for zoneID: String) -> Bool {
        loadStateStore.isZoneResourceLoaded(.emailRouting, zoneID: zoneID)
    }

    func isEmailSendingLoaded(for zoneID: String) -> Bool {
        loadStateStore.isZoneResourceLoaded(.emailSending, zoneID: zoneID)
    }

    func isEmailDestinationAddressesLoaded(for accountID: String) -> Bool {
        loadStateStore.isAccountResourceLoaded(.emailDestinationAddresses, accountID: accountID)
    }

    func markEmailRoutingLoaded(zoneID: String) {
        loadStateStore.markZoneResourceLoaded(.emailRouting, zoneID: zoneID)
        zoneStore.lastRefreshAt = Date()
    }

    func markEmailSendingLoaded(zoneID: String) {
        loadStateStore.markZoneResourceLoaded(.emailSending, zoneID: zoneID)
        zoneStore.lastRefreshAt = Date()
    }

    func markEmailDestinationAddressesLoaded(accountID: String) {
        loadStateStore.markAccountResourceLoaded(.emailDestinationAddresses, accountID: accountID)
    }

    func presentError(_ error: some Error) {
        shellActions.presentError(error)
    }

    func presentAPIError(_ message: String) {
        shellActions.presentError(CloudflareAPIError.api(message))
    }

    func presentNotice(_ message: String) {
        shellActions.presentNotice(message)
    }

    func logDebug(_ message: String) {
        shellActions.logDebug(message)
    }

    func withMailLoading<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let count = loadingStore.begin(.mail)
        shellActions.logDebug("Started \(LoadingActivity.mail.rawValue) activity. Active count: \(count).")
        defer {
            let count = loadingStore.end(.mail)
            shellActions.logDebug("Finished \(LoadingActivity.mail.rawValue) activity. Active count: \(count).")
        }
        return try await operation()
    }

    func partialResult<T>(
        _ operation: () async throws -> T
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
}
