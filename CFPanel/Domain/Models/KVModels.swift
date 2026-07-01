import Foundation

nonisolated struct KVNamespace: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let title: String
    let supportsURLEncoding: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case supportsURLEncoding = "supports_url_encoding"
    }
}

nonisolated struct KVNamespaceKey: Identifiable, Hashable, Decodable, Sendable {
    let name: String
    let expiration: Int?
    let metadata: JSONValue?

    var id: String { name }

    var expirationDate: Date? {
        guard let expiration else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(expiration))
    }

    var metadataSummary: String? {
        guard let metadata else { return nil }
        switch metadata {
        case .object(let object):
            if object.isEmpty {
                return "Metadata configured"
            }
            return object.keys.sorted().joined(separator: ", ")
        case .array(let array):
            return array.isEmpty ? "Metadata configured" : "\(array.count) metadata items"
        case .string(let value):
            return value
        case .number(let value):
            return value.formatted()
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return nil
        }
    }
}

nonisolated struct KVNamespaceKeyPage: Sendable {
    let keys: [KVNamespaceKey]
    let nextCursor: String?

    var hasMore: Bool {
        nextCursor?.isEmpty == false
    }
}

nonisolated struct KVValueSnapshot: Identifiable, Hashable, Sendable {
    static let previewByteLimit = 256 * 1024

    let keyName: String
    let value: String
    let isValueTruncated: Bool
    let isBinary: Bool
    let expiration: Date?
    let metadata: JSONValue?
    let contentType: String?
    let byteCount: Int

    var id: String { keyName }

    var contentTypeTitle: String {
        guard let contentType, contentType.isEmpty == false else { return "unknown" }
        return contentType
    }

    var valuePreviewTitle: String {
        if isBinary {
            return "Binary payload"
        }
        if isValueTruncated {
            return "Preview limited to \(Self.previewByteLimit / 1024) KB"
        }
        return "Full value"
    }
}

nonisolated struct KVBulkWriteEntry: Hashable, Codable, Sendable {
    let key: String
    let value: String
    let expiration: Int?
    let expirationTTL: Int?
    let metadata: JSONValue?

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case expiration
        case expirationTTL = "expiration_ttl"
        case metadata
    }
}

nonisolated struct KVBulkMutationResult: Decodable, Sendable {
    let successfulKeyCount: Int?
    let unsuccessfulKeys: [String]?

    enum CodingKeys: String, CodingKey {
        case successfulKeyCount = "successful_key_count"
        case unsuccessfulKeys = "unsuccessful_keys"
    }
}
