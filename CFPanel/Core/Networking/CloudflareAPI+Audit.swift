import Foundation

extension CloudflareAPI {
    func listAccountAuditLogs(
        accountID: String,
        since: Date,
        before: Date,
        zoneID: String?,
        limit: Int = 100
    ) async throws -> AuditLogPage {
        var components = URLComponents()
        components.path = "/accounts/\(accountID)/logs/audit"
        components.queryItems = [
            URLQueryItem(name: "since", value: iso8601String(from: since)),
            URLQueryItem(name: "before", value: iso8601String(from: before)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let zoneID, zoneID.isEmpty == false {
            components.queryItems?.append(URLQueryItem(name: "zone_id", value: zoneID))
        }

        let requestPath = components.path + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
        let envelope: CloudflareEnvelope<[AuditLogEntry]> = try await requestEnvelope(path: requestPath)

        guard envelope.success else {
            let message = envelope.errors?.first?.message
                ?? envelope.messages?.first?.message
                ?? "Cloudflare returned an empty audit log response."
            throw CloudflareAPIError.api(message)
        }

        return AuditLogPage(
            entries: envelope.result ?? [],
            resultInfo: envelope.resultInfo
        )
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
