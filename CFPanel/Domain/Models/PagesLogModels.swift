import Foundation

nonisolated struct PagesDeploymentLogResponse: Decodable, Sendable {
    let data: [PagesDeploymentLogEntry]
    let includesContainerLogs: Bool?
    let total: Int?

    enum CodingKeys: String, CodingKey {
        case data
        case includesContainerLogs = "includes_container_logs"
        case total
    }
}

nonisolated struct PagesDeploymentLogEntry: Identifiable, Hashable, Decodable, Sendable {
    let id: String
    let level: String?
    let message: String?
    let timestamp: Date?
    let rawValue: JSONValue

    var levelTitle: String {
        level?.replacingOccurrences(of: "_", with: " ").localizedUppercase ?? "LOG"
    }

    var displayMessage: String {
        if let message, message.isEmpty == false {
            return message
        }

        return rawValue.prettyPrintedString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        let explicitID = try container.decodeIfPresent(String.self, forKey: .init("id"))
        let message = try container.decodeIfPresent(String.self, forKey: .init("message"))
            ?? container.decodeIfPresent(String.self, forKey: .init("msg"))
        let level = try container.decodeIfPresent(String.self, forKey: .init("level"))
            ?? container.decodeIfPresent(String.self, forKey: .init("severity"))
        let timestamp =
            try container.decodeIfPresent(Date.self, forKey: .init("timestamp"))
            ?? container.decodeIfPresent(Date.self, forKey: .init("ts"))
            ?? container.decodeIfPresent(Date.self, forKey: .init("created_on"))

        var rawObject: [String: JSONValue] = [:]
        for key in container.allKeys {
            rawObject[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }

        self.message = message
        self.level = level
        self.timestamp = timestamp
        self.rawValue = .object(rawObject)
        self.id = explicitID
            ?? Self.makeFallbackID(message: message, level: level, timestamp: timestamp, rawObject: rawObject)
            ?? UUID().uuidString
    }

    private static func makeFallbackID(
        message: String?,
        level: String?,
        timestamp: Date?,
        rawObject: [String: JSONValue]
    ) -> String? {
        let components = [
            message ?? "",
            level ?? "",
            timestamp?.timeIntervalSince1970.description ?? "",
            rawObject.keys.sorted().joined(separator: ",")
        ]
        let key = components.joined(separator: "|")
        guard key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        return String(key.hashValue)
    }
}
