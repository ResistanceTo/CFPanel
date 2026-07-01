import Foundation

enum KVOperationLimits {
    static let maxBulkKeys = 10_000
    static let maxBulkWritePayloadBytes = 100 * 1024 * 1024
    static let maxValueBytes = 25 * 1024 * 1024
    static let maxMetadataBytes = 1_024
    static let minExpirationTTL = 60

    static func validateKey(_ key: String) throws {
        guard key.utf8.isEmpty == false else {
            throw CloudflareAPIError.api("KV key cannot be empty.")
        }
    }

    static func validateValue(_ value: String) throws {
        let byteCount = value.utf8.count
        guard byteCount <= maxValueBytes else {
            throw CloudflareAPIError.api("KV value is larger than Cloudflare's 25 MiB limit.")
        }
    }

    static func validateMetadata(_ metadata: JSONValue?) throws {
        guard let metadata else { return }
        let byteCount = try JSONEncoder().encode(metadata).count
        guard byteCount <= maxMetadataBytes else {
            throw CloudflareAPIError.api("KV metadata is larger than Cloudflare's 1 KiB limit.")
        }
    }

    static func validateExpirationTTL(_ ttl: Int?) throws {
        guard let ttl else { return }
        guard ttl >= minExpirationTTL else {
            throw CloudflareAPIError.api("KV expiration TTL must be at least 60 seconds.")
        }
    }

    static func validateSingleWrite(
        key: String,
        value: String,
        metadata: JSONValue?,
        expirationTTL: Int?
    ) throws {
        try validateKey(key)
        try validateValue(value)
        try validateMetadata(metadata)
        try validateExpirationTTL(expirationTTL)
    }

    static func validateBulkWritePayload(_ rawValue: String) throws {
        guard rawValue.utf8.count <= maxBulkWritePayloadBytes else {
            throw CloudflareAPIError.api("Bulk write payload is larger than Cloudflare's 100 MB request limit.")
        }
    }

    static func validateBulkWriteEntries(_ entries: [KVBulkWriteEntry]) throws {
        guard entries.isEmpty == false else {
            throw CloudflareAPIError.api("Bulk write needs at least one KV entry.")
        }
        guard entries.count <= maxBulkKeys else {
            throw CloudflareAPIError.api("Bulk write can include at most 10,000 keys.")
        }

        for entry in entries {
            try validateSingleWrite(
                key: entry.key,
                value: entry.value,
                metadata: entry.metadata,
                expirationTTL: entry.expirationTTL
            )
        }
    }

    static func validateBulkDeleteKeys(_ keys: [String]) throws {
        guard keys.isEmpty == false else {
            throw CloudflareAPIError.api("Bulk delete needs at least one key.")
        }
        guard keys.count <= maxBulkKeys else {
            throw CloudflareAPIError.api("Bulk delete can include at most 10,000 keys.")
        }

        for key in keys {
            try validateKey(key)
        }
    }
}
