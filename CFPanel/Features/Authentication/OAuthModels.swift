import Foundation

struct OAuthTokenPayload: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scope: String

    var grantedScopes: [String] {
        scope
            .split(separator: " ")
            .map(String.init)
            .filter { $0.isEmpty == false }
            .sorted()
    }
}

struct OAuthUserInfo: Codable, Sendable {
    let email: String?
    let name: String?
}

struct OAuthAccount: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let type: String?
}

struct OAuthCallbackPayload: Sendable {
    let code: String
    let state: String
}
