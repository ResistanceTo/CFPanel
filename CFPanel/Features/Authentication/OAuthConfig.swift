import Foundation

nonisolated enum OAuthConfig {
    static let clientIDKey = "CFPANEL_CLOUDFLARE_OAUTH_CLIENT_ID"
    static let redirectURIKey = "CFPANEL_CLOUDFLARE_OAUTH_REDIRECT_URI"
    static let callbackScheme = "cfpanel"
    static let callbackHost = "oauth"

    static let authorizationURL = URL(string: "https://dash.cloudflare.com/oauth2/auth")!
    static let tokenURL = URL(string: "https://dash.cloudflare.com/oauth2/token")!
    static let revokeURL = URL(string: "https://dash.cloudflare.com/oauth2/revoke")!
    static let userInfoURL = URL(string: "https://dash.cloudflare.com/oauth2/userinfo")!

    static var clientID: String? {
        resolvedValue(forInfoKey: clientIDKey)
    }

    static var redirectURI: String? {
        resolvedValue(forInfoKey: redirectURIKey)
    }

    static var isConfigured: Bool {
        guard let clientID, let redirectURI else { return false }
        return clientID.isEmpty == false && redirectURI.isEmpty == false
    }

    nonisolated static func callbackURL() -> URL {
        URL(string: "\(callbackScheme)://\(callbackHost)/callback")!
    }

    private static func resolvedValue(forInfoKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
