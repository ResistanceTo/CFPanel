import Foundation

@MainActor
final class SecurityWorkspaceContext {
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

    var currentSecurityLevel: SecurityLevel {
        get { zoneStore.currentSecurityLevel }
        set { zoneStore.currentSecurityLevel = newValue }
    }

    var lastNonAttackSecurityLevel: SecurityLevel {
        get { zoneStore.lastNonAttackSecurityLevel }
        set { zoneStore.lastNonAttackSecurityLevel = newValue }
    }

    var isUnderAttackModeEnabled: Bool {
        zoneStore.isUnderAttackModeEnabled
    }

    var isPerformingPanicAction: Bool {
        loadingStore.isPerformingPanicAction
    }

    var isRefreshingZoneControls: Bool {
        loadingStore.isRefreshingZoneControls
    }

    func isSecurityLoaded(for zoneID: String) -> Bool {
        loadStateStore.isZoneResourceLoaded(.security, zoneID: zoneID)
    }

    func markSecurityLoaded(zoneID: String) {
        loadStateStore.markZoneResourceLoaded(.security, zoneID: zoneID)
        zoneStore.lastRefreshAt = Date()
    }

    func makeZoneRequestContext() -> ZoneRequestContext? {
        sessionStore.makeZoneRequestContext(zoneID: selectedZoneID)
    }

    func isCurrent(_ context: ZoneRequestContext) -> Bool {
        sessionStore.isCurrent(context, selectedZoneID: selectedZoneID)
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

    func withZoneControlsRefresh<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        try await withLoadingActivity(.zoneControls, operation)
    }

    func withPanicAction<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        try await withLoadingActivity(.panicAction, operation)
    }

    private func withLoadingActivity<T>(
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
}
