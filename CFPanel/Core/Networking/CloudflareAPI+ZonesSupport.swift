import Foundation

nonisolated struct ZonePausedUpdate: Encodable, Sendable {
    let paused: Bool
}

nonisolated struct SecurityHeaderSettingValue: Codable, Sendable {
    let strictTransportSecurity: HSTSSettings?

    enum CodingKeys: String, CodingKey {
        case strictTransportSecurity = "strict_transport_security"
    }
}

nonisolated struct SecurityHeaderResponse: Decodable, Sendable {
    let value: SecurityHeaderSettingValue?
}

nonisolated struct SecurityHeaderUpdatePayload: Encodable, Sendable {
    let value: SecurityHeaderSettingValue
}

nonisolated struct ZoneSettingUpdate: Encodable, Sendable {
    let value: String
}

nonisolated struct ZoneSettingResponse: Decodable, Sendable {
    let id: String
    let value: String
}

nonisolated struct ZoneSettingValueUpdate: Encodable, Sendable {
    let value: JSONValue
}

nonisolated struct ZoneSettingValueResponse: Decodable, Sendable {
    let id: String
    let editable: Bool?
    let value: JSONValue?

    var boolValue: Bool {
        switch value {
        case .bool(let boolValue):
            boolValue
        case .string(let stringValue):
            ["on", "true", "enabled"].contains(stringValue.lowercased())
        case .number(let numberValue):
            numberValue != 0
        default:
            false
        }
    }

    var stringValue: String {
        switch value {
        case .string(let stringValue):
            stringValue
        case .bool(let boolValue):
            boolValue ? "on" : "off"
        case .number(let numberValue):
            String(numberValue)
        default:
            ""
        }
    }
}

nonisolated struct PurgeEverythingRequest: Encodable, Sendable {
    let purgeEverything: Bool

    enum CodingKeys: String, CodingKey {
        case purgeEverything = "purge_everything"
    }
}

nonisolated struct PurgeURLRequest: Encodable, Sendable {
    let files: [String]
}

nonisolated struct PurgeCacheResponse: Decodable, Sendable {
    let id: String
}
