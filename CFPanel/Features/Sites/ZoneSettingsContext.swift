import Foundation

@MainActor
final class ZoneSettingsContext {
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

    var zoneDetails: CloudflareZoneDetails? {
        get { zoneStore.zoneDetails }
        set { zoneStore.zoneDetails = newValue }
    }

    var zoneDNSSettings: ZoneDNSSettings? {
        get { zoneStore.zoneDNSSettings }
        set { zoneStore.zoneDNSSettings = newValue }
    }

    var zoneControls: ZoneControlSettings {
        get { zoneStore.zoneControls }
        set { zoneStore.zoneControls = newValue }
    }

    var unavailableZoneControls: [ZoneControlToggle: String] {
        get { zoneStore.unavailableZoneControls }
        set { zoneStore.unavailableZoneControls = newValue }
    }

    var zoneAdvancedSettings: ZoneAdvancedSettings {
        get { zoneStore.zoneAdvancedSettings }
        set { zoneStore.zoneAdvancedSettings = newValue }
    }

    var unavailableZoneAdvancedSettings: [ZoneAdvancedToggle: String] {
        get { zoneStore.unavailableZoneAdvancedSettings }
        set { zoneStore.unavailableZoneAdvancedSettings = newValue }
    }

    var edgeTLSSettings: EdgeTLSSettings {
        get { zoneStore.edgeTLSSettings }
        set { zoneStore.edgeTLSSettings = newValue }
    }

    var zoneCacheSettings: ZoneCacheSettings {
        get { zoneStore.zoneCacheSettings }
        set { zoneStore.zoneCacheSettings = newValue }
    }

    var isRefreshingZoneControls: Bool {
        loadingStore.isRefreshingZoneControls
    }

    func isLoaded(_ resource: ZoneLoadResourceKind, for zoneID: String) -> Bool {
        loadStateStore.isZoneResourceLoaded(resource, zoneID: zoneID)
    }

    func markLoaded(_ resource: ZoneLoadResourceKind, zoneID: String) {
        loadStateStore.markZoneResourceLoaded(resource, zoneID: zoneID)
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

    func withZoneControlsRefresh<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        try await withLoadingActivity(.zoneControls, operation)
    }

    private func withLoadingActivity<T>(
        _ activity: LoadingActivity,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let count = loadingStore.begin(activity)
        shellActions.logDebug("Started \(activity.rawValue) activity. Active count: \(count).")
        defer {
            let count = loadingStore.end(activity)
            shellActions.logDebug("Finished \(activity.rawValue) activity. Active count: \(count).")
        }
        return try await operation()
    }
}
