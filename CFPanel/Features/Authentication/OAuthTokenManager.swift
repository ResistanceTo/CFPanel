import Foundation

actor OAuthTokenManager {
    static let shared = OAuthTokenManager()

    private var refreshTask: Task<OAuthTokenPayload, Error>?

    func currentValidPayload() async throws -> OAuthTokenPayload? {
        OAuthDiagnostics.notice("Loading current OAuth token payload from secure storage.")
        guard let payload = try await MainActor.run(body: {
            try OAuthTokenStore.load()
        }) else {
            OAuthDiagnostics.notice("No stored OAuth token payload was found.")
            return nil
        }

        if payload.expiresAt > Date().addingTimeInterval(120) {
            OAuthDiagnostics.notice(
                "Stored OAuth token is still valid until \(OAuthDiagnostics.describeDate(payload.expiresAt))."
            )
            return payload
        }

        OAuthDiagnostics.notice("Stored OAuth token is close to expiry and will be refreshed.")
        return try await refreshPayloadIfNeeded()
    }

    func refreshPayloadIfNeeded() async throws -> OAuthTokenPayload? {
        OAuthDiagnostics.notice("Checking whether stored OAuth token needs refresh.")
        guard let payload = try await MainActor.run(body: {
            try OAuthTokenStore.load()
        }) else {
            OAuthDiagnostics.notice("Refresh skipped because no stored OAuth token payload exists.")
            return nil
        }

        if payload.expiresAt > Date().addingTimeInterval(120) {
            OAuthDiagnostics.notice(
                "Refresh skipped because stored OAuth token remains valid until \(OAuthDiagnostics.describeDate(payload.expiresAt))."
            )
            return payload
        }

        if let refreshTask {
            OAuthDiagnostics.notice("Awaiting existing in-flight OAuth refresh task.")
            return try await refreshTask.value
        }

        let task = Task<OAuthTokenPayload, Error> {
            OAuthDiagnostics.notice("Creating a new OAuth refresh task.")
            let coordinator = await MainActor.run { OAuthCoordinator() }
            let refreshed = try await coordinator.refreshTokenIfNeeded(payload)
            try await MainActor.run(body: {
                try OAuthTokenStore.save(refreshed)
            })
            OAuthDiagnostics.notice(
                "Saved refreshed OAuth token payload with expiry \(OAuthDiagnostics.describeDate(refreshed.expiresAt))."
            )
            return refreshed
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    func clear() async {
        OAuthDiagnostics.notice("Clearing OAuth token manager state.")
        refreshTask?.cancel()
        refreshTask = nil
    }
}
