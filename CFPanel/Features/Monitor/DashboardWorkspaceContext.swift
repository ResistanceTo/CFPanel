import Foundation

@MainActor
final class DashboardWorkspaceContext {
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

    var zones: [CloudflareZone] {
        zoneStore.zones
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

    var dashboard: DashboardSnapshot {
        get { zoneStore.dashboard }
        set { zoneStore.dashboard = newValue }
    }

    var isRefreshingDashboard: Bool {
        loadingStore.isRefreshingDashboard
    }

    var resolvedAccountID: String? {
        resolvedAccountContext?.accountID
    }

    func openSitesTab() {
        shellActions.selectTab(.sites)
    }

    func presentError(_ error: some Error) {
        shellActions.presentError(error)
    }

    func isDashboardLoaded(for zoneID: String, range: DashboardTimeRange) -> Bool {
        loadStateStore.isDashboardLoaded(for: zoneID, range: range)
    }

    func markDashboardLoaded(zoneID: String, range: DashboardTimeRange) {
        loadStateStore.markDashboardLoaded(zoneID: zoneID, range: range)
        zoneStore.lastRefreshAt = Date()
    }

    func markZoneOverviewLoaded(zoneID: String) {
        loadStateStore.markZoneResourceLoaded(.zoneOverview, zoneID: zoneID)
    }

    func requireAccountID(_ message: String) throws -> String {
        guard let context = validateAccountContext() else {
            throw CloudflareAPIError.api(
                TokenPermissionGuidance.accountCapabilityMessage(message, tokenMode: sessionStore.tokenMode)
            )
        }
        return context.accountID
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

    func withDashboardRefresh<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let count = loadingStore.begin(.dashboard)
        logDebug("Started \(LoadingActivity.dashboard.rawValue) activity. Active count: \(count).")
        defer {
            let count = loadingStore.end(.dashboard)
            logDebug("Finished \(LoadingActivity.dashboard.rawValue) activity. Active count: \(count).")
        }
        return try await operation()
    }

    private var resolvedAccountContext: ResolvedAccountContext? {
        let normalizedInput = sessionStore.accountIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedInput.isEmpty == false else { return nil }
        return ResolvedAccountContext(accountID: normalizedInput, source: "account token input")
    }

    private func validateAccountContext() -> ResolvedAccountContext? {
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

    private func isLikelyCloudflareAccountID(_ value: String) -> Bool {
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return value.count == 32 && value.unicodeScalars.allSatisfy { hexCharacterSet.contains($0) }
    }
}
