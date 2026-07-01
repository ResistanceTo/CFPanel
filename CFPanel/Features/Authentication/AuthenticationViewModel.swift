import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
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
    @ObservationIgnored
    private let credentialPersistence: CredentialPersistenceService
    @ObservationIgnored
    private let workspaceLoader: AuthenticatedWorkspaceLoader
    @ObservationIgnored
    private let oauthCoordinator = OAuthCoordinator()
    @ObservationIgnored
    private let oauthSessionStore = OAuthSessionStore()

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
        credentialPersistence = CredentialPersistenceService(
            api: api,
            sessionStore: sessionStore,
            shellActions: shellActions
        )
        workspaceLoader = AuthenticatedWorkspaceLoader(
            api: api,
            sessionStore: sessionStore,
            zoneStore: zoneStore,
            shellActions: shellActions
        )

        NotificationCenter.default.addObserver(
            forName: .cfpanelOAuthCallbackReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let url = notification.object as? URL else { return }
            OAuthDiagnostics.notice(
                "AuthenticationViewModel received OAuth callback notification \(OAuthDiagnostics.describeURL(url))."
            )
            Task { @MainActor [weak self] in
                await self?.handleOAuthCallback(url)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .cfpanelOAuthCallbackFailed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let receivedError = notification.object as? Error
            Task { @MainActor [weak self] in
                if let receivedError {
                    OAuthDiagnostics.error(
                        "AuthenticationViewModel received OAuth failure notification: \(receivedError.localizedDescription)"
                    )
                } else {
                    OAuthDiagnostics.error("AuthenticationViewModel received OAuth failure notification without an error payload.")
                }
                self?.oauthSessionStore.resetPendingAuthorization()
                if let error = receivedError {
                    self?.shellActions.presentError(error)
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var authenticationMethod: AuthenticationMethod {
        get { sessionStore.authenticationMethod }
        set { sessionStore.authenticationMethod = newValue }
    }

    var authTokenMode: AuthTokenMode {
        get { sessionStore.tokenMode }
        set { sessionStore.tokenMode = newValue }
    }

    var accountIDInput: String {
        get { sessionStore.accountIDInput }
        set { sessionStore.accountIDInput = newValue }
    }

    var isSignedIn: Bool {
        sessionStore.isSignedIn
    }

    var isBootstrapping: Bool {
        sessionStore.isBootstrapping
    }

    var isAuthenticating: Bool {
        sessionStore.isAuthenticating
    }

    var isAuthorizingWithOAuth: Bool {
        oauthSessionStore.isAuthorizing
    }

    var tokenInput: String {
        get { sessionStore.tokenInput }
        set { sessionStore.tokenInput = newValue }
    }

    var credentialStorageMode: CredentialStorageMode {
        get { sessionStore.credentialStorageMode }
        set { sessionStore.credentialStorageMode = newValue }
    }

    var tokenVerification: TokenVerification? {
        sessionStore.tokenVerification
    }

    var oauthPermissions: [OAuthFeaturePermission] {
        oauthSessionStore.permissions
    }

    var oauthSelectedScopes: [String] {
        oauthSessionStore.selectedScopes
    }

    var selectedOAuthPreset: OAuthPermissionPreset? {
        oauthSessionStore.selectedPreset
    }

    var oauthAccountName: String {
        sessionStore.oauthAccountName
    }

    var oauthGrantedScopes: [String] {
        sessionStore.oauthGrantedScopes
    }

    var isOAuthConfigured: Bool {
        OAuthConfig.isConfigured
    }

    func bootstrap(
        preferredZoneID: String,
        fallbackTokenMode: AuthTokenMode,
        fallbackAccountID: String
    ) async {
        guard sessionStore.isBootstrapping == false else { return }

        shellActions.logNotice("Bootstrapping saved Cloudflare session.")
        sessionStore.isBootstrapping = true
        defer { sessionStore.isBootstrapping = false }

        do {
            let selectedStorageMode = sessionStore.credentialStorageMode
            let lookup = try credentialPersistence.loadSavedCredentials(
                storageMode: selectedStorageMode,
                fallbackTokenMode: fallbackTokenMode,
                fallbackAccountID: fallbackAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            guard let credentials = lookup.credentials else {
                shellActions.logDebug("No saved Cloudflare credentials found during bootstrap.")
                return
            }

            let normalizedToken: String
            if credentials.authenticationMethod == .oauth {
                guard let oauthPayload = try await OAuthTokenManager.shared.currentValidPayload() else {
                    try credentialPersistence.deleteAllCredentials()
                    return
                }
                normalizedToken = oauthPayload.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
                sessionStore.oauthGrantedScopes = oauthPayload.grantedScopes
            } else {
                normalizedToken = credentials.token.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let normalizedAccountID = credentials.normalizedAccountID
            guard normalizedToken.isEmpty == false else {
                try credentialPersistence.deleteAllCredentials()
                return
            }

            if lookup.didLoadLegacyCredentials {
                try credentialPersistence.migrateLegacyCredentials(credentials, to: selectedStorageMode)
            }

            sessionStore.authenticationMethod = credentials.authenticationMethod
            sessionStore.oauthAccountName = credentials.oauthAccountName ?? ""
            sessionStore.oauthGrantedScopes = credentials.oauthGrantedScopes ?? []

            try await establishAuthenticatedSession(
                token: normalizedToken,
                tokenMode: credentials.tokenMode,
                accountID: normalizedAccountID,
                preferredZoneID: preferredZoneID,
                mirrorTokenInput: false,
                authenticationMethod: credentials.authenticationMethod
            )
        } catch {
            shellActions.logError("Failed to bootstrap session: \(error.localizedDescription)")
            advanceSessionRevision(reason: "clearing failed bootstrap runtime session")
            clearSessionState(clearConnectionSettings: false)
            let apiSessionVersion = sessionStore.takeAPISessionVersion()
            Task {
                await api.clearToken(ifVersion: apiSessionVersion)
            }
            shellActions.presentError(error)
        }
    }

    func signIn(
        preferredZoneID: String,
        tokenMode: AuthTokenMode,
        accountID: String
    ) async {
        let token = sessionStore.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.isEmpty == false else {
            shellActions.presentErrorMessage("Paste a Cloudflare API token to continue.")
            return
        }

        let normalizedAccountID = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        if tokenMode == .account, normalizedAccountID.isEmpty {
            shellActions.presentErrorMessage(TokenPermissionGuidance.accountContextMessage(tokenMode: .account))
            return
        }

        shellActions.logNotice("Starting Cloudflare sign-in.")
        sessionStore.isAuthenticating = true
        defer { sessionStore.isAuthenticating = false }

        do {
            try await establishAuthenticatedSession(
                token: token,
                tokenMode: tokenMode,
                accountID: normalizedAccountID,
                preferredZoneID: preferredZoneID,
                mirrorTokenInput: true,
                authenticationMethod: .accountToken
            )
        } catch {
            shellActions.presentError(error)
        }
    }

    func startOAuthAuthorization() {
        OAuthDiagnostics.notice(
            """
            User initiated Cloudflare OAuth login. configured=\(OAuthConfig.isConfigured) \
            clientID=\(OAuthDiagnostics.redactSecret(OAuthConfig.clientID)) \
            selectedScopes=\(oauthSessionStore.selectedScopes.joined(separator: ", "))
            """
        )
        do {
            try oauthCoordinator.startAuthorization(
                scopes: oauthSessionStore.scopeString,
                sessionStore: oauthSessionStore
            )
        } catch {
            OAuthDiagnostics.error("Failed to start Cloudflare OAuth login: \(error.localizedDescription)")
            oauthSessionStore.resetPendingAuthorization()
            shellActions.presentError(error)
        }
    }

    func toggleOAuthPermission(_ permissionID: String) {
        oauthSessionStore.togglePermission(permissionID)
    }

    func toggleOAuthEditPermission(_ permissionID: String) {
        oauthSessionStore.toggleEditPermission(permissionID)
    }

    func applyOAuthPreset(_ preset: OAuthPermissionPreset) {
        oauthSessionStore.applyPreset(preset)
    }

    func signOut() {
        shellActions.logNotice("Signing out of Cloudflare session.")
        Task {
            await OAuthTokenManager.shared.clear()
            if sessionStore.authenticationMethod == .oauth,
               let payload = try? OAuthTokenStore.load()
            {
                await oauthCoordinator.revokeCurrentToken(payload)
                try? OAuthTokenStore.delete()
            }

            let credentialDeletionError = clearPersistedSession(clearConnectionSettings: true)
            if let credentialDeletionError {
                shellActions.presentErrorMessage(
                    """
                    Signed out locally, but failed to remove saved credentials.

                    \(credentialDeletionError.localizedDescription)
                    """
                )
            }
        }
    }

    func updateCredentialStorageMode(_ mode: CredentialStorageMode) async {
        let previousMode = sessionStore.credentialStorageMode
        guard previousMode != mode else { return }

        do {
            try await credentialPersistence.persistCurrentCredentials(to: mode, previousMode: previousMode)
            sessionStore.credentialStorageMode = mode
            shellActions.presentNotice("Token storage updated.")
        } catch {
            shellActions.presentError(error)
        }
    }

    @discardableResult
    func invalidateSessionForUnauthorized() -> String? {
        shellActions.logNotice("Invalidating session after unauthorized response.")
        advanceSessionRevision(reason: "invalidating unauthorized runtime session")
        clearSessionState(clearConnectionSettings: false)
        let apiSessionVersion = sessionStore.takeAPISessionVersion()

        Task {
            await api.clearToken(ifVersion: apiSessionVersion)
        }

        return nil
    }

    private func establishAuthenticatedSession(
        token: String,
        tokenMode: AuthTokenMode,
        accountID: String,
        preferredZoneID: String,
        mirrorTokenInput: Bool,
        authenticationMethod: AuthenticationMethod
    ) async throws {
        shellActions.logDebug("Establishing authenticated Cloudflare session.")
        try await verifySession(
            token: token,
            tokenMode: tokenMode,
            accountID: accountID,
            mirrorTokenInput: mirrorTokenInput,
            authenticationMethod: authenticationMethod
        )
        credentialPersistence.persistAuthenticatedSession(
            token: token,
            tokenMode: tokenMode,
            accountID: accountID,
            authenticationMethod: authenticationMethod,
            oauthAccountName: sessionStore.oauthAccountName.isEmpty ? nil : sessionStore.oauthAccountName,
            oauthGrantedScopes: sessionStore.oauthGrantedScopes
        )
        sessionStore.clearSensitiveTokenState()
        await workspaceLoader.refreshAuthenticatedWorkspace(preferredZoneID: preferredZoneID)
    }

    private func verifySession(
        token: String,
        tokenMode: AuthTokenMode,
        accountID: String,
        mirrorTokenInput: Bool,
        authenticationMethod: AuthenticationMethod
    ) async throws {
        advanceSessionRevision(reason: "verifying Cloudflare credentials")
        sessionStore.authenticationMethod = authenticationMethod
        sessionStore.tokenMode = tokenMode
        sessionStore.accountIDInput = accountID
        sessionStore.tokenVerification = nil
        sessionStore.isSignedIn = false

        if mirrorTokenInput {
            sessionStore.tokenInput = token
        } else {
            sessionStore.clearSensitiveTokenState()
        }

        do {
            let version = await api.configure(token: token)
            sessionStore.storeAPISessionVersion(version)
            if authenticationMethod == .oauth {
                sessionStore.tokenVerification = TokenVerification(
                    id: "oauth",
                    status: .active,
                    expiresOn: nil,
                    notBefore: nil
                )
            } else {
                sessionStore.tokenVerification = try await api.verifyToken(
                    mode: tokenMode,
                    accountID: accountID
                )
            }
            sessionStore.isSignedIn = true
            shellActions.logNotice("Cloudflare token verified successfully.")
        } catch {
            let version = sessionStore.takeAPISessionVersion()
            await api.clearToken(ifVersion: version)
            sessionStore.tokenVerification = nil
            sessionStore.isSignedIn = false
            shellActions.logError("Cloudflare token verification failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func handleOAuthCallback(_ url: URL) async {
        OAuthDiagnostics.notice("Beginning OAuth callback handling in AuthenticationViewModel.")
        do {
            let callback = try oauthCoordinator.handleCallbackURL(url, sessionStore: oauthSessionStore)
            oauthSessionStore.statusMessage = "Exchanging Cloudflare authorization..."
            OAuthDiagnostics.notice(
                "OAuth callback parsed successfully. code=\(OAuthDiagnostics.redactSecret(callback.code)) state=\(OAuthDiagnostics.redactSecret(callback.state))."
            )
            let payload = try await oauthCoordinator.exchangeCodeForToken(
                callback: callback,
                sessionStore: oauthSessionStore
            )
            OAuthDiagnostics.notice(
                """
                Received OAuth token payload. refreshTokenPresent=\(payload.refreshToken?.isEmpty == false) \
                expiresAt=\(OAuthDiagnostics.describeDate(payload.expiresAt)) \
                grantedScopes=\(payload.grantedScopes.joined(separator: ", "))
                """
            )
            let refreshedPayload = try await oauthCoordinator.refreshTokenIfNeeded(payload)
            try OAuthTokenStore.save(refreshedPayload)
            OAuthDiagnostics.notice(
                """
                Persisted OAuth token payload. expiresAt=\(OAuthDiagnostics.describeDate(refreshedPayload.expiresAt)) \
                grantedScopes=\(refreshedPayload.grantedScopes.joined(separator: ", "))
                """
            )

            let userInfo = await oauthCoordinator.fetchUserInfo(accessToken: refreshedPayload.accessToken)
            let accounts = try await oauthCoordinator.fetchAccounts(accessToken: refreshedPayload.accessToken)
            let resolvedAccountID = accounts.first?.id ?? ""
            let resolvedAccountName = userInfo?.email ?? userInfo?.name ?? accounts.first?.name ?? ""

            OAuthDiagnostics.notice(
                """
                OAuth identity resolved. accountCount=\(accounts.count) \
                selectedAccountID=\(OAuthDiagnostics.redactSecret(resolvedAccountID)) \
                selectedAccountName=\(resolvedAccountName.isEmpty ? "<empty>" : resolvedAccountName)
                """
            )

            guard resolvedAccountID.isEmpty == false else {
                OAuthDiagnostics.error("OAuth flow finished without any accessible Cloudflare account.")
                throw CloudflareAPIError.api("Cloudflare OAuth succeeded, but no accessible account was returned.")
            }

            sessionStore.oauthAccountName = resolvedAccountName
            sessionStore.oauthGrantedScopes = refreshedPayload.grantedScopes
            OAuthDiagnostics.notice("Establishing authenticated app session from OAuth token.")

            try await establishAuthenticatedSession(
                token: refreshedPayload.accessToken,
                tokenMode: .account,
                accountID: resolvedAccountID,
                preferredZoneID: zoneStore.selectedZoneID ?? "",
                mirrorTokenInput: false,
                authenticationMethod: .oauth
            )

            oauthSessionStore.resetPendingAuthorization()
            OAuthDiagnostics.notice("OAuth login flow completed successfully.")
        } catch {
            OAuthDiagnostics.error("OAuth callback handling failed: \(error.localizedDescription)")
            oauthSessionStore.resetPendingAuthorization()
            shellActions.presentError(error)
        }
    }

    private func clearPersistedSession(clearConnectionSettings: Bool) -> Error? {
        advanceSessionRevision(
            reason: clearConnectionSettings
                ? "clearing persisted session"
                : "clearing unauthorized session"
        )
        let credentialDeletionError = credentialPersistence.deletePersistedCredentials(
            storageMode: sessionStore.credentialStorageMode
        )
        clearSessionState(clearConnectionSettings: clearConnectionSettings)
        let apiSessionVersion = sessionStore.takeAPISessionVersion()

        Task {
            await api.clearToken(ifVersion: apiSessionVersion)
        }

        return credentialDeletionError
    }

    private func clearSessionState(clearConnectionSettings: Bool) {
        sessionStore.resetAuthenticationState(clearConnectionSettings: clearConnectionSettings)
        zoneStore.clearWorkspace()
        resetZoneScopedState()
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

    private func advanceSessionRevision(reason: String) {
        let revision = sessionStore.advanceSessionRevision()
        shellActions.logDebug("Advanced session revision to \(revision) (\(reason)).")
    }
}
