import Foundation
import OSLog
import SwiftUI

actor CloudflareAPI {
    static let shared = CloudflareAPI()
    static let logger = Logger(subsystem: "org.zhaohe.CFPanel", category: "CloudflareAPI")
    nonisolated static let verboseLoggingEnabled =
        ProcessInfo.processInfo.environment["CFPANEL_VERBOSE_LOGGING"] == "1"

    let baseURL = URL(string: "https://api.cloudflare.com/client/v4/")!
    let session: URLSession
    let decoder: JSONDecoder
    let encoder: JSONEncoder
    var token: String?
    var tokenVersion: UInt64 = 0
    var oauthTokenRefreshHandler: (@Sendable () async throws -> String?)?

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration)
        }

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    @discardableResult
    func configure(token: String?) -> UInt64 {
        self.token = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        tokenVersion &+= 1
        logDebug("Configured API session version \(tokenVersion). Token present: \(self.token?.isEmpty == false).")
        return tokenVersion
    }

    func clearToken(ifVersion expectedVersion: UInt64) {
        guard expectedVersion != 0 else {
            logDebug("Skipped token clear because no API session version was captured.")
            return
        }

        guard tokenVersion == expectedVersion else {
            logDebug("Skipped token clear for stale API session version \(expectedVersion). Current version: \(tokenVersion).")
            return
        }

        token = nil
        tokenVersion &+= 1
        logNotice("Cleared API token for session version \(expectedVersion).")
    }

    func currentToken() -> String? {
        token
    }

    func setOAuthTokenRefreshHandler(
        _ handler: @escaping @Sendable () async throws -> String?
    ) {
        oauthTokenRefreshHandler = handler
    }

    func logDebug(_ message: @autoclosure () -> String) {
        guard Self.verboseLoggingEnabled else { return }
        let resolvedMessage = message()
        Self.logger.debug("\(resolvedMessage, privacy: .public)")
    }

    func logNotice(_ message: @autoclosure () -> String) {
        guard Self.verboseLoggingEnabled else { return }
        let resolvedMessage = message()
        Self.logger.notice("\(resolvedMessage, privacy: .public)")
    }

    func logError(_ message: @autoclosure () -> String) {
        let resolvedMessage = message()
        Self.logger.error("\(resolvedMessage, privacy: .public)")
    }
}
