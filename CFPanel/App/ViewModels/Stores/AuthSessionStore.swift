import Foundation
import Observation

@MainActor
@Observable
final class AuthSessionStore {
    var authenticationMethod: AuthenticationMethod = .accountToken
    var tokenMode: AuthTokenMode = .account
    var accountIDInput = ""
    var oauthAccountName = ""
    var oauthGrantedScopes: [String] = []
    var isSignedIn = false
    var isBootstrapping = false
    var isAuthenticating = false
    var tokenInput = ""
    var tokenVerification: TokenVerification?
    var credentialStorageMode: CredentialStorageMode = .persistedDefault {
        didSet {
            credentialStorageMode.persistAsDefault()
        }
    }

    @ObservationIgnored
    private var sessionRevision: UInt64 = 0
    @ObservationIgnored
    private var apiSessionVersion: UInt64 = 0

    func resetAuthenticationState(clearConnectionSettings: Bool) {
        tokenInput = ""
        if clearConnectionSettings {
            authenticationMethod = .accountToken
            accountIDInput = ""
            tokenMode = .account
            oauthAccountName = ""
            oauthGrantedScopes = []
        }
        isSignedIn = false
        tokenVerification = nil
    }

    func clearSensitiveTokenState() {
        tokenInput = ""
    }

    func makeSessionRequestContext() -> SessionRequestContext {
        SessionRequestContext(sessionRevision: sessionRevision)
    }

    func makeZoneRequestContext(zoneID: String?) -> ZoneRequestContext? {
        guard let zoneID else { return nil }
        return ZoneRequestContext(sessionRevision: sessionRevision, zoneID: zoneID)
    }

    func makeAccountRequestContext(accountID: String?) -> AccountRequestContext? {
        guard let accountID else { return nil }
        return AccountRequestContext(sessionRevision: sessionRevision, accountID: accountID)
    }

    func makeAccountRequestContext(accountID: String) -> AccountRequestContext {
        AccountRequestContext(sessionRevision: sessionRevision, accountID: accountID)
    }

    func isCurrent(_ context: SessionRequestContext) -> Bool {
        sessionRevision == context.sessionRevision && isSignedIn
    }

    func isCurrent(_ context: ZoneRequestContext, selectedZoneID: String?) -> Bool {
        sessionRevision == context.sessionRevision
            && selectedZoneID == context.zoneID
            && isSignedIn
    }

    func isCurrent(_ context: AccountRequestContext, resolvedAccountID: String?) -> Bool {
        sessionRevision == context.sessionRevision
            && resolvedAccountID == context.accountID
            && isSignedIn
    }

    func advanceSessionRevision() -> UInt64 {
        sessionRevision &+= 1
        return sessionRevision
    }

    func storeAPISessionVersion(_ version: UInt64) {
        apiSessionVersion = version
    }

    func takeAPISessionVersion() -> UInt64 {
        let version = apiSessionVersion
        apiSessionVersion = 0
        return version
    }
}
