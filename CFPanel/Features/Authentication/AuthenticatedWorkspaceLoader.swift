import Foundation

@MainActor
final class AuthenticatedWorkspaceLoader {
    private let api: CloudflareAPI
    private let sessionStore: AuthSessionStore
    private let zoneStore: ZoneWorkspaceStore
    private let shellActions: AppShellActions

    init(
        api: CloudflareAPI,
        sessionStore: AuthSessionStore,
        zoneStore: ZoneWorkspaceStore,
        shellActions: AppShellActions
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.zoneStore = zoneStore
        self.shellActions = shellActions
    }

    func refreshAuthenticatedWorkspace(preferredZoneID: String) async {
        do {
            try await refreshZones(preferredZoneID: preferredZoneID)
        } catch {
            shellActions.presentError(error)
        }
    }

    func refreshZones(preferredZoneID: String) async throws {
        let requestContext = sessionStore.makeSessionRequestContext()
        let resolvedZones = try await api.listZones().sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        guard sessionStore.isCurrent(requestContext) else {
            shellActions.logDebug("Discarded stale zone list response.")
            return
        }

        zoneStore.zones = resolvedZones
        if zoneStore.zones.isEmpty {
            zoneStore.selectedZoneID = nil
        } else if preferredZoneID.isEmpty == false, zoneStore.zones.contains(where: { $0.id == preferredZoneID }) {
            zoneStore.selectedZoneID = preferredZoneID
        } else {
            zoneStore.selectedZoneID = zoneStore.zones.first?.id
        }
    }
}
