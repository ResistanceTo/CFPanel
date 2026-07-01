import AuthenticationServices
import Foundation
import OSLog
import UIKit

nonisolated enum OAuthDiagnostics {
    private static let logger = Logger(subsystem: "org.zhaohe.CFPanel", category: "OAuth")
    private static let sensitiveQueryItemNames: Set<String> = [
        "access_token",
        "client_id",
        "code",
        "code_challenge",
        "code_verifier",
        "refresh_token",
        "state",
        "token"
    ]

    static func notice(_ message: @autoclosure () -> String) {
        let resolvedMessage = message()
        logger.notice("\(resolvedMessage, privacy: .public)")
#if DEBUG
        print("[CFPanel OAuth] \(resolvedMessage)")
#endif
    }

    static func error(_ message: @autoclosure () -> String) {
        let resolvedMessage = message()
        logger.error("\(resolvedMessage, privacy: .public)")
#if DEBUG
        print("[CFPanel OAuth] ERROR \(resolvedMessage)")
#endif
    }

    static func redactSecret(_ value: String?, prefix: Int = 6, suffix: Int = 4) -> String {
        guard let value else { return "<nil>" }
        guard value.isEmpty == false else { return "<empty>" }
        let visibleCount = prefix + suffix
        guard value.count > visibleCount else { return String(repeating: "*", count: value.count) }
        let prefixValue = String(value.prefix(prefix))
        let suffixValue = String(value.suffix(suffix))
        return "\(prefixValue)...\(suffixValue)"
    }

    static func describeURL(_ url: URL?) -> String {
        guard let url else { return "<nil-url>" }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        components.queryItems = components.queryItems?.map { item in
            guard let value = item.value else { return item }
            if sensitiveQueryItemNames.contains(item.name) {
                return URLQueryItem(name: item.name, value: redactSecret(value))
            }
            return item
        }

        return components.string ?? url.absoluteString
    }

    static func describeDate(_ date: Date) -> String {
        date.ISO8601Format()
    }

    static func describeScopes(_ scopes: String) -> String {
        let scopeList = scopes
            .split(separator: " ")
            .map(String.init)
            .filter { $0.isEmpty == false }
            .sorted()
        return "\(scopeList.count) scope(s): \(scopeList.joined(separator: ", "))"
    }
}

@MainActor
final class OAuthCoordinator {
    private var webAuthenticationSession: ASWebAuthenticationSession?
    private let presentationContextProvider = WebAuthPresentationContextProvider()

    func startAuthorization(
        scopes: String,
        sessionStore: OAuthSessionStore
    ) throws {
        guard let clientID = OAuthConfig.clientID,
              let redirectURI = OAuthConfig.redirectURI else {
            OAuthDiagnostics.error("OAuth start aborted because client configuration is missing.")
            throw CloudflareAPIError.api(
                "Cloudflare OAuth is not configured yet. Add CFPANEL_CLOUDFLARE_OAUTH_CLIENT_ID and CFPANEL_CLOUDFLARE_OAUTH_REDIRECT_URI to Info.plist first."
            )
        }

        let verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)
        let state = UUID().uuidString

        var components = URLComponents(url: OAuthConfig.authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authorizationURL = components.url else {
            OAuthDiagnostics.error("Failed to construct Cloudflare authorization URL.")
            throw CloudflareAPIError.invalidRequest
        }

        OAuthDiagnostics.notice(
            """
            Starting Cloudflare OAuth. clientID=\(OAuthDiagnostics.redactSecret(clientID)) \
            redirectURI=\(redirectURI) \
            scopes=\(OAuthDiagnostics.describeScopes(scopes)) \
            authorizationURL=\(OAuthDiagnostics.describeURL(authorizationURL))
            """
        )

        sessionStore.pendingState = state
        sessionStore.pendingCodeVerifier = verifier
        sessionStore.isAuthorizing = true
        sessionStore.statusMessage = "Waiting for Cloudflare authorization..."
        OAuthDiagnostics.notice(
            "Stored pending OAuth state=\(OAuthDiagnostics.redactSecret(state)) verifierPresent=\(verifier.isEmpty == false)."
        )

        let completion: (URL?, (any Error)?) -> Void = { callbackURL, error in
            if let callbackURL {
                OAuthDiagnostics.notice(
                    "ASWebAuthenticationSession completed with callback URL \(OAuthDiagnostics.describeURL(callbackURL))."
                )
                NotificationCenter.default.post(
                    name: .cfpanelOAuthCallbackReceived,
                    object: callbackURL
                )
            } else if let error {
                OAuthDiagnostics.error(
                    "ASWebAuthenticationSession failed before callback. error=\(error.localizedDescription)"
                )
                NotificationCenter.default.post(
                    name: .cfpanelOAuthCallbackFailed,
                    object: error
                )
            } else {
                OAuthDiagnostics.error("ASWebAuthenticationSession ended without callback URL or explicit error.")
                NotificationCenter.default.post(
                    name: .cfpanelOAuthCallbackFailed,
                    object: ASWebAuthenticationSessionError(.canceledLogin)
                )
            }
        }

        let session: ASWebAuthenticationSession
        if #available(iOS 17.4, *) {
            session = ASWebAuthenticationSession(
                url: authorizationURL,
                callback: .customScheme(OAuthConfig.callbackScheme),
                completionHandler: completion
            )
        } else {
            session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: OAuthConfig.callbackScheme,
                completionHandler: completion
            )
        }

        session.presentationContextProvider = presentationContextProvider
        session.prefersEphemeralWebBrowserSession = false
        OAuthDiagnostics.notice(
            "Launching ASWebAuthenticationSession. callbackScheme=\(OAuthConfig.callbackScheme) ephemeral=false"
        )
        webAuthenticationSession = session
        session.start()
    }

    func handleCallbackURL(_ url: URL, sessionStore: OAuthSessionStore) throws -> OAuthCallbackPayload {
        OAuthDiagnostics.notice("Handling OAuth callback URL \(OAuthDiagnostics.describeURL(url)).")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            OAuthDiagnostics.error("OAuth callback could not be parsed into query items.")
            throw CloudflareAPIError.api("Cloudflare OAuth returned an invalid callback.")
        }

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value
            OAuthDiagnostics.error(
                "OAuth callback returned error=\(error) description=\(description ?? "<none>")."
            )
            if error == "invalid_scope", let description, description.isEmpty == false {
                let suggestedMessage = """
                Cloudflare OAuth client scope configuration is incomplete.

                \(description)

                Open your Cloudflare OAuth client settings and add the missing scope to the client before signing in again.
                """
                throw CloudflareAPIError.api(suggestedMessage)
            }
            if let description, description.isEmpty == false {
                throw CloudflareAPIError.api("\(error): \(description)")
            }
            throw CloudflareAPIError.api(error)
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value,
              let state = queryItems.first(where: { $0.name == "state" })?.value
        else {
            OAuthDiagnostics.error("OAuth callback is missing code or state.")
            throw CloudflareAPIError.api("Cloudflare OAuth callback is missing the authorization code.")
        }

        guard let pendingState = sessionStore.pendingState, pendingState == state else {
            OAuthDiagnostics.error(
                """
                OAuth state validation failed. expected=\(OAuthDiagnostics.redactSecret(sessionStore.pendingState)) \
                received=\(OAuthDiagnostics.redactSecret(state))
                """
            )
            throw CloudflareAPIError.api("Cloudflare OAuth state validation failed. Please try again.")
        }

        OAuthDiagnostics.notice(
            "OAuth callback validated successfully. code=\(OAuthDiagnostics.redactSecret(code)) state=\(OAuthDiagnostics.redactSecret(state))."
        )
        return OAuthCallbackPayload(code: code, state: state)
    }

    func exchangeCodeForToken(
        callback: OAuthCallbackPayload,
        sessionStore: OAuthSessionStore
    ) async throws -> OAuthTokenPayload {
        guard let clientID = OAuthConfig.clientID,
              let redirectURI = OAuthConfig.redirectURI,
              let verifier = sessionStore.pendingCodeVerifier
        else {
            OAuthDiagnostics.error("Token exchange aborted because OAuth runtime configuration is incomplete.")
            throw CloudflareAPIError.api("Cloudflare OAuth configuration is incomplete.")
        }

        var request = URLRequest(url: OAuthConfig.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "grant_type": "authorization_code",
            "client_id": clientID,
            "code": callback.code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier
        ])

        OAuthDiagnostics.notice(
            """
            Exchanging authorization code for token. tokenURL=\(OAuthConfig.tokenURL.absoluteString) \
            clientID=\(OAuthDiagnostics.redactSecret(clientID)) \
            redirectURI=\(redirectURI) \
            code=\(OAuthDiagnostics.redactSecret(callback.code)) \
            verifierPresent=\(verifier.isEmpty == false)
            """
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            OAuthDiagnostics.error("Token exchange failed because response was not HTTP.")
            throw CloudflareAPIError.invalidResponse
        }
        OAuthDiagnostics.notice("Token exchange returned HTTP \(httpResponse.statusCode).")
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            OAuthDiagnostics.error(
                "Token exchange failed. status=\(httpResponse.statusCode) body=\(body.isEmpty ? "<empty>" : body)"
            )
            throw CloudflareAPIError.api(
                body.isEmpty ? "Cloudflare OAuth token exchange failed." : body
            )
        }

        struct TokenResponse: Decodable {
            let accessToken: String
            let refreshToken: String?
            let expiresIn: Int
            let scope: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case expiresIn = "expires_in"
                case scope
            }
        }

        let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
        OAuthDiagnostics.notice(
            """
            Token exchange succeeded. refreshTokenPresent=\(payload.refreshToken?.isEmpty == false) \
            expiresIn=\(payload.expiresIn)s \
            scopes=\(payload.scope ?? "<empty>")
            """
        )
        return OAuthTokenPayload(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn)),
            scope: payload.scope ?? ""
        )
    }

    func refreshTokenIfNeeded(_ payload: OAuthTokenPayload) async throws -> OAuthTokenPayload {
        guard payload.expiresAt <= Date().addingTimeInterval(120),
              let refreshToken = payload.refreshToken,
              let clientID = OAuthConfig.clientID else {
            OAuthDiagnostics.notice(
                """
                Skipping OAuth token refresh. expiresAt=\(OAuthDiagnostics.describeDate(payload.expiresAt)) \
                refreshTokenPresent=\(payload.refreshToken?.isEmpty == false) \
                clientIDPresent=\(OAuthConfig.clientID?.isEmpty == false)
                """
            )
            return payload
        }

        var request = URLRequest(url: OAuthConfig.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken
        ])

        OAuthDiagnostics.notice(
            """
            Refreshing OAuth access token. tokenURL=\(OAuthConfig.tokenURL.absoluteString) \
            clientID=\(OAuthDiagnostics.redactSecret(clientID)) \
            refreshToken=\(OAuthDiagnostics.redactSecret(refreshToken)) \
            expiresAt=\(OAuthDiagnostics.describeDate(payload.expiresAt))
            """
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            OAuthDiagnostics.error("Refresh token request failed because response was not HTTP.")
            throw CloudflareAPIError.invalidResponse
        }
        OAuthDiagnostics.notice("Refresh token request returned HTTP \(httpResponse.statusCode).")
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            OAuthDiagnostics.error(
                "Refresh token request failed. status=\(httpResponse.statusCode) body=\(body.isEmpty ? "<empty>" : body)"
            )
            throw CloudflareAPIError.unauthorized
        }

        struct TokenResponse: Decodable {
            let accessToken: String
            let refreshToken: String?
            let expiresIn: Int
            let scope: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case expiresIn = "expires_in"
                case scope
            }
        }

        let refreshed = try JSONDecoder().decode(TokenResponse.self, from: data)
        OAuthDiagnostics.notice(
            """
            OAuth token refresh succeeded. refreshTokenReused=\(refreshed.refreshToken == nil) \
            expiresIn=\(refreshed.expiresIn)s \
            scopes=\(refreshed.scope ?? payload.scope)
            """
        )
        return OAuthTokenPayload(
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(refreshed.expiresIn)),
            scope: refreshed.scope ?? payload.scope
        )
    }

    func fetchUserInfo(accessToken: String) async -> OAuthUserInfo? {
        var request = URLRequest(url: OAuthConfig.userInfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        OAuthDiagnostics.notice(
            "Requesting OAuth user info. url=\(OAuthConfig.userInfoURL.absoluteString) accessToken=\(OAuthDiagnostics.redactSecret(accessToken))."
        )

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            OAuthDiagnostics.error("OAuth user info request failed.")
            return nil
        }

        let userInfo = try? JSONDecoder().decode(OAuthUserInfo.self, from: data)
        OAuthDiagnostics.notice(
            "OAuth user info resolved. email=\(userInfo?.email ?? "<nil>") name=\(userInfo?.name ?? "<nil>")."
        )
        return userInfo
    }

    func fetchAccounts(accessToken: String) async throws -> [OAuthAccount] {
        var request = URLRequest(url: URL(string: "https://api.cloudflare.com/client/v4/accounts")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        OAuthDiagnostics.notice("Requesting Cloudflare accounts available to OAuth user.")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            OAuthDiagnostics.error("Accounts lookup failed because response was not HTTP.")
            throw CloudflareAPIError.invalidResponse
        }
        OAuthDiagnostics.notice("Accounts lookup returned HTTP \(httpResponse.statusCode).")
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            OAuthDiagnostics.error(
                "Accounts lookup failed. status=\(httpResponse.statusCode) body=\(body.isEmpty ? "<empty>" : body)"
            )
            throw CloudflareAPIError.api(
                body.isEmpty ? "Cloudflare OAuth could not resolve available accounts." : body
            )
        }

        let envelope = try JSONDecoder().decode(CloudflareEnvelope<[OAuthAccount]>.self, from: data)
        guard envelope.success else {
            let message = envelope.errors?.first?.diagnosticText ?? "Cloudflare OAuth could not resolve available accounts."
            OAuthDiagnostics.error("Accounts lookup returned success=false message=\(message)")
            throw CloudflareAPIError.api(message)
        }

        let accounts = envelope.result ?? []
        let names = accounts.prefix(3).map(\.name).joined(separator: ", ")
        OAuthDiagnostics.notice("Accounts lookup succeeded. count=\(accounts.count) sample=\(names)")
        return accounts
    }

    func revokeCurrentToken(_ payload: OAuthTokenPayload) async {
        guard let clientID = OAuthConfig.clientID else { return }

        var request = URLRequest(url: OAuthConfig.revokeURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "client_id": clientID,
            "token": payload.refreshToken ?? payload.accessToken
        ])

        OAuthDiagnostics.notice(
            "Revoking OAuth token. clientID=\(OAuthDiagnostics.redactSecret(clientID)) token=\(OAuthDiagnostics.redactSecret(payload.refreshToken ?? payload.accessToken))."
        )
        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse {
            OAuthDiagnostics.notice("OAuth revoke request returned HTTP \(httpResponse.statusCode).")
        } else {
            OAuthDiagnostics.error("OAuth revoke request did not return an HTTP response.")
        }
    }

    private static func formBody(_ parameters: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")

        return parameters
            .map { key, value in
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(key)=\(encodedValue)"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }
}

@MainActor
private final class WebAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            preconditionFailure("No foreground UIWindowScene is available for OAuth.")
        }
        return UIWindow(windowScene: scene)
    }
}

extension Notification.Name {
    static let cfpanelOAuthCallbackReceived = Notification.Name("cfpanel.oauth.callback.received")
    static let cfpanelOAuthCallbackFailed = Notification.Name("cfpanel.oauth.callback.failed")
}
