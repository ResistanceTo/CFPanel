import Foundation

nonisolated struct HyperdriveConfig: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let name: String
    let origin: JSONValue?
    let caching: JSONValue?
    let createdOn: Date?
    let modifiedOn: Date?
    let mTLS: JSONValue?
    let originConnectionLimit: Int?
    let rawValue: JSONValue

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case origin
        case caching
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case mTLS = "mtls"
        case originConnectionLimit = "origin_connection_limit"
    }

    var host: String? {
        origin?.objectValue?["host"]?.stringValue
    }

    var port: Int? {
        origin?.objectValue?["port"]?.intValue
    }

    var database: String? {
        origin?.objectValue?["database"]?.stringValue
    }

    var user: String? {
        origin?.objectValue?["user"]?.stringValue
            ?? origin?.objectValue?["username"]?.stringValue
    }

    var scheme: String? {
        origin?.objectValue?["scheme"]?.stringValue
    }

    var usesAccessProtectedOrigin: Bool {
        origin?.objectValue?["access_client_id"]?.stringValue?.isEmpty == false
    }

    var cachingEnabled: Bool {
        if let disabled = caching?.objectValue?["disabled"]?.boolValue {
            return disabled == false
        }
        if let maxAge = caching?.objectValue?["max_age"]?.intValue {
            return maxAge > 0
        }
        return caching != nil
    }

    var cachingSummary: String {
        guard let caching else { return "Caching unavailable" }
        guard let object = caching.objectValue else { return "Caching configured" }

        if let disabled = object["disabled"]?.boolValue, disabled {
            return "Caching disabled"
        }

        var parts: [String] = []
        if let maxAge = object["max_age"]?.intValue {
            parts.append("max_age \(maxAge)s")
        }
        if let staleWhileRevalidate = object["stale_while_revalidate"]?.intValue {
            parts.append("swr \(staleWhileRevalidate)s")
        }

        return parts.isEmpty ? "Caching enabled" : parts.joined(separator: "  ·  ")
    }

    var originSummary: String {
        let location = [host, port.map(String.init)].compactMap { $0 }.joined(separator: ":")
        let details = [database, scheme]
            .compactMap { $0 }
            .joined(separator: "  ·  ")

        if location.isEmpty == false, details.isEmpty == false {
            return "\(location)  ·  \(details)"
        }
        if location.isEmpty == false {
            return location
        }
        return details.isEmpty ? "Origin unavailable" : details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        id = try container.decode(String.self, forKey: .init("id"))
        name = try container.decode(String.self, forKey: .init("name"))
        origin = try container.decodeIfPresent(JSONValue.self, forKey: .init("origin"))
        caching = try container.decodeIfPresent(JSONValue.self, forKey: .init("caching"))
        createdOn = try container.decodeIfPresent(Date.self, forKey: .init("created_on"))
        modifiedOn = try container.decodeIfPresent(Date.self, forKey: .init("modified_on"))
        mTLS = try container.decodeIfPresent(JSONValue.self, forKey: .init("mtls"))
        originConnectionLimit = try container.decodeIfPresent(Int.self, forKey: .init("origin_connection_limit"))

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        rawValue = .object(rawObject)
    }
}
