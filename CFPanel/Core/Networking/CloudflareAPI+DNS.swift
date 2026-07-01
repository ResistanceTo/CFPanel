import Foundation

extension CloudflareAPI {
    func listDNSRecords(zoneID: String) async throws -> [DNSRecord] {
        try await requestAllPages(path: "/zones/\(zoneID)/dns_records", perPage: 200)
    }

    func listScannedDNSRecords(zoneID: String) async throws -> [DNSRecord] {
        try await request(path: "/zones/\(zoneID)/dns_records/scan/review")
    }

    func exportDNSRecords(zoneID: String) async throws -> String {
        try await requestString(path: "/zones/\(zoneID)/dns_records/export")
    }

    func importDNSRecords(
        zoneID: String,
        fileName: String,
        fileData: Data,
        proxied: Bool
    ) async throws -> DNSImportResponse {
        let formFields = [
            MultipartFormField(
                name: "proxied",
                data: Data((proxied ? "true" : "false").utf8),
                mimeType: "text/plain"
            ),
            MultipartFormField(
                name: "file",
                data: fileData,
                fileName: fileName,
                mimeType: "text/plain"
            )
        ]

        return try await multipartRequest(
            path: "/zones/\(zoneID)/dns_records/import",
            fields: formFields
        )
    }

    func triggerDNSScan(zoneID: String) async throws {
        try await requestWithoutResult(
            path: "/zones/\(zoneID)/dns_records/scan/trigger",
            method: "POST"
        )
    }

    func reviewScannedDNSRecords(
        zoneID: String,
        accepts: [JSONValue],
        rejects: [String]
    ) async throws -> DNSScanReviewResponse {
        try await request(
            path: "/zones/\(zoneID)/dns_records/scan/review",
            method: "POST",
            body: DNSScanReviewRequest(
                accepts: accepts,
                rejects: rejects
            )
        )
    }

    func createDNSRecord(zoneID: String, draft: DNSRecordDraft) async throws -> DNSRecord {
        let payload = DNSRecordPayload(draft: draft)
        return try await request(
            path: "/zones/\(zoneID)/dns_records",
            method: "POST",
            body: payload
        )
    }

    func updateDNSRecord(zoneID: String, recordID: String, draft: DNSRecordDraft) async throws -> DNSRecord {
        let payload = DNSRecordPayload(draft: draft)
        return try await request(
            path: "/zones/\(zoneID)/dns_records/\(recordID)",
            method: "PUT",
            body: payload
        )
    }

    func deleteDNSRecord(zoneID: String, recordID: String) async throws {
        _ = try await request(
            path: "/zones/\(zoneID)/dns_records/\(recordID)",
            method: "DELETE"
        ) as DeleteResponse
    }
}

nonisolated private struct DNSScanReviewRequest: Encodable, Sendable {
    let accepts: [JSONValue]
    let rejects: [String]
}

nonisolated private struct DNSRecordPayload: Encodable, Sendable {
    let type: String
    let name: String
    let content: String?
    let data: [String: JSONValue]?
    let ttl: Int
    let proxied: Bool?
    let priority: Int?
    let comment: String?

    init(draft: DNSRecordDraft) {
        type = draft.type.rawValue
        name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        content = draft.usesStructuredData ? nil : draft.trimmedContent
        data = draft.structuredDataPayload
        ttl = draft.resolvedTTL
        proxied = draft.type.supportsProxied ? draft.proxied : nil
        priority = draft.type.supportsPriority && draft.usesStructuredData == false ? draft.resolvedPriority : nil
        comment = draft.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : draft.comment.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension DNSRecordDraft {
    nonisolated var structuredDataPayload: [String: JSONValue]? {
        guard usesStructuredData else { return nil }

        return type.dataFields.reduce(into: [:]) { partialResult, field in
            guard let value = trimmedData[field.key], value.isEmpty == false else { return }

            switch field.valueKind {
            case .integer:
                if let intValue = Int(value) {
                    partialResult[field.key] = .number(Double(intValue))
                }
            case .string:
                partialResult[field.key] = .string(value)
            }
        }
    }
}
