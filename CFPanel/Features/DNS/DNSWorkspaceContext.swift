import Foundation

@MainActor
final class DNSWorkspaceContext {
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

    var isRefreshingDNS: Bool {
        loadingStore.isRefreshingDNS
    }

    func requireSelectedZoneID(_ message: String) throws -> String {
        guard let selectedZoneID else {
            throw CloudflareAPIError.api(message)
        }
        return selectedZoneID
    }

    func isDNSLoaded(for zoneID: String) -> Bool {
        loadStateStore.isZoneResourceLoaded(.dns, zoneID: zoneID)
    }

    func markDNSLoaded(zoneID: String) {
        loadStateStore.markZoneResourceLoaded(.dns, zoneID: zoneID)
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

    func presentNotice(_ message: String) {
        shellActions.presentNotice(message)
    }

    func logDebug(_ message: String) {
        shellActions.logDebug(message)
    }

    func withDNSRefresh<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let count = loadingStore.begin(.dns)
        logDebug("Started \(LoadingActivity.dns.rawValue) activity. Active count: \(count).")
        defer {
            let count = loadingStore.end(.dns)
            logDebug("Finished \(LoadingActivity.dns.rawValue) activity. Active count: \(count).")
        }
        return try await operation()
    }
}
