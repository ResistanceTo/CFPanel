import Foundation
import Observation

@MainActor
@Observable
final class SitesViewModel {
    @ObservationIgnored
    private let api: CloudflareAPI
    @ObservationIgnored
    private let sessionStore: AuthSessionStore
    @ObservationIgnored
    private let zoneStore: ZoneWorkspaceStore
    @ObservationIgnored
    private let dnsStore: DNSStore
    @ObservationIgnored
    private let emailRoutingStore: EmailRoutingStore
    @ObservationIgnored
    private let emailSendingStore: EmailSendingStore
    @ObservationIgnored
    private let rulesStore: RulesStore
    @ObservationIgnored
    private let accountStore: AccountServicesStore
    @ObservationIgnored
    private let loadStateStore: ResourceLoadStateStore
    @ObservationIgnored
    private let shellActions: AppShellActions

    init(
        api: CloudflareAPI,
        sessionStore: AuthSessionStore,
        zoneStore: ZoneWorkspaceStore,
        dnsStore: DNSStore,
        emailRoutingStore: EmailRoutingStore,
        emailSendingStore: EmailSendingStore,
        rulesStore: RulesStore,
        accountStore: AccountServicesStore,
        loadStateStore: ResourceLoadStateStore,
        shellActions: AppShellActions
    ) {
        self.api = api
        self.sessionStore = sessionStore
        self.zoneStore = zoneStore
        self.dnsStore = dnsStore
        self.emailRoutingStore = emailRoutingStore
        self.emailSendingStore = emailSendingStore
        self.rulesStore = rulesStore
        self.accountStore = accountStore
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

    func refreshWorkspace(preferredZoneID: String) async {
        shellActions.logNotice("Refreshing authenticated workspace.")

        do {
            let normalizedAccountID = sessionStore.accountIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if sessionStore.authenticationMethod == .oauth {
                sessionStore.tokenVerification = TokenVerification(
                    id: "oauth",
                    status: .active,
                    expiresOn: nil,
                    notBefore: nil
                )
            } else {
                sessionStore.tokenVerification = try await api.verifyToken(
                    mode: sessionStore.tokenMode,
                    accountID: normalizedAccountID
                )
            }

            let persistedToken = await api.currentToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if persistedToken.isEmpty == false {
                persistAuthenticatedSession(
                    token: persistedToken,
                    tokenMode: sessionStore.tokenMode,
                    accountID: normalizedAccountID
                )
            }

            try await refreshZones(preferredZoneID: preferredZoneID)
        } catch {
            shellActions.presentError(error)
        }
    }

    func switchSelectedZone(_ zoneID: String) {
        guard zones.isEmpty == false else { return }
        guard selectedZoneID != zoneID else { return }
        guard zones.contains(where: { $0.id == zoneID }) else { return }

        shellActions.logNotice("Switching active zone context.")
        zoneStore.selectedZoneID = zoneID
        resetZoneScopedState()
    }

    private func refreshZones(preferredZoneID: String) async throws {
        let requestContext = sessionStore.makeSessionRequestContext()
        let resolvedZones = try await api.listZones().sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        guard sessionStore.isCurrent(requestContext) else {
            shellActions.logDebug("Discarded stale zone list response.")
            return
        }

        zoneStore.zones = resolvedZones
        if zones.isEmpty {
            zoneStore.selectedZoneID = nil
        } else if preferredZoneID.isEmpty == false, zones.contains(where: { $0.id == preferredZoneID }) {
            zoneStore.selectedZoneID = preferredZoneID
        } else {
            zoneStore.selectedZoneID = zones.first?.id
        }
    }

    private func persistAuthenticatedSession(
        token: String,
        tokenMode: AuthTokenMode,
        accountID: String
    ) {
        do {
            try KeychainTokenStore.save(
                credentials: StoredCloudflareCredentials(
                    token: token,
                    tokenMode: tokenMode,
                    accountID: accountID,
                    authenticationMethod: sessionStore.authenticationMethod,
                    oauthAccountName: sessionStore.oauthAccountName.isEmpty ? nil : sessionStore.oauthAccountName,
                    oauthGrantedScopes: sessionStore.oauthGrantedScopes
                ),
                storageMode: sessionStore.credentialStorageMode
            )
        } catch {
            shellActions.presentError(error)
        }
    }

    private func resetZoneScopedState() {
        WorkspaceStateResetter.resetZoneScopedState(
            zoneStore: zoneStore,
            dnsStore: dnsStore,
            emailRoutingStore: emailRoutingStore,
            emailSendingStore: emailSendingStore,
            rulesStore: rulesStore,
            accountStore: accountStore,
            loadStateStore: loadStateStore
        )
    }
}
