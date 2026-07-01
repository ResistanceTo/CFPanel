import Foundation

@MainActor
final class RulesWorkspaceContext {
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

    var isRefreshingRules: Bool {
        loadingStore.isRefreshingRules
    }

    func isPhaseLoaded(_ phase: CloudflareRulesetPhase, for zoneID: String) -> Bool {
        loadStateStore.isRulesPhaseLoaded(phase, for: zoneID)
    }

    func markPhaseLoaded(_ phase: CloudflareRulesetPhase, zoneID: String) {
        loadStateStore.markRulesPhaseLoaded(phase, zoneID: zoneID)
        zoneStore.lastRefreshAt = Date()
    }

    func requireSelectedZoneID(_ message: String) throws -> String {
        guard let selectedZoneID else {
            throw CloudflareAPIError.api(message)
        }
        return selectedZoneID
    }

    func requireZoneRequestContext(_ message: String) throws -> ZoneRequestContext {
        guard let context = makeZoneRequestContext() else {
            throw CloudflareAPIError.api(message)
        }
        return context
    }

    func makeZoneRequestContext() -> ZoneRequestContext? {
        sessionStore.makeZoneRequestContext(zoneID: selectedZoneID)
    }

    func isCurrent(_ context: ZoneRequestContext) -> Bool {
        sessionStore.isCurrent(context, selectedZoneID: selectedZoneID)
    }

    func logDebug(_ message: String) {
        shellActions.logDebug(message)
    }

    func withRulesLoading<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let count = loadingStore.begin(.rules)
        logDebug("Started \(LoadingActivity.rules.rawValue) activity. Active count: \(count).")
        defer {
            let count = loadingStore.end(.rules)
            logDebug("Finished \(LoadingActivity.rules.rawValue) activity. Active count: \(count).")
        }
        return try await operation()
    }
}
