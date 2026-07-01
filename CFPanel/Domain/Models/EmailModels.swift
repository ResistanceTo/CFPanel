import Foundation
import SwiftUI

nonisolated struct EmailRoutingSettings: Decodable, Sendable {
    let id: String?
    let created: Date?
    let enabled: Bool
    let modified: Date?
    let name: String?
    let skipWizard: Bool?
    let status: String?
    let synced: Date?
    let tag: String?

    enum CodingKeys: String, CodingKey {
        case id
        case created
        case enabled
        case modified
        case name
        case skipWizard = "skip_wizard"
        case status
        case synced
        case tag
    }

    init(
        id: String? = nil,
        created: Date? = nil,
        enabled: Bool = false,
        modified: Date? = nil,
        name: String? = nil,
        skipWizard: Bool? = nil,
        status: String? = nil,
        synced: Date? = nil,
        tag: String? = nil
    ) {
        self.id = id
        self.created = created
        self.enabled = enabled
        self.modified = modified
        self.name = name
        self.skipWizard = skipWizard
        self.status = status
        self.synced = synced
        self.tag = tag
    }

    init(resultValue: JSONValue) {
        guard let object = resultValue.objectValue else {
            self.init()
            return
        }

        let nestedObject = object["result"]?.objectValue ?? object
        self.init(
            id: nestedObject["id"]?.stringValue,
            created: Self.decodeDate(from: nestedObject["created"]),
            enabled: Self.decodeBool(from: nestedObject["enabled"])
                ?? Self.decodeBool(from: nestedObject["active"])
                ?? Self.decodeBool(from: nestedObject["is_enabled"])
                ?? false,
            modified: Self.decodeDate(from: nestedObject["modified"]),
            name: nestedObject["name"]?.stringValue,
            skipWizard: Self.decodeBool(from: nestedObject["skip_wizard"]),
            status: nestedObject["status"]?.stringValue,
            synced: Self.decodeDate(from: nestedObject["synced"]),
            tag: nestedObject["tag"]?.stringValue
        )
    }

    private static func decodeBool(from value: JSONValue?) -> Bool? {
        switch value {
        case .bool(let bool):
            return bool
        case .string(let string):
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "on", "enabled", "active"].contains(normalized) {
                return true
            }
            if ["false", "off", "disabled", "inactive"].contains(normalized) {
                return false
            }
            return nil
        case .number(let number):
            return number != 0
        default:
            return nil
        }
    }

    private static func decodeDate(from value: JSONValue?) -> Date? {
        guard case .string(let string)? = value else {
            return nil
        }
        return ISO8601DateFormatter().date(from: string)
    }
}

nonisolated struct EmailRoutingDNSStatus: Decodable, Sendable {
    let records: [EmailDNSRecord]
    let errors: [EmailRoutingDNSIssue]

    init(records: [EmailDNSRecord], errors: [EmailRoutingDNSIssue]) {
        self.records = records
        self.errors = errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        records =
            (try? container.decode([EmailDNSRecord].self, forKey: AnyCodingKey("records"))) ??
            (try? container.decode([EmailDNSRecord].self, forKey: AnyCodingKey("record"))) ??
            []
        errors = (try? container.decode([EmailRoutingDNSIssue].self, forKey: AnyCodingKey("errors"))) ?? []
    }

    init(resultValue: JSONValue) {
        guard let object = resultValue.objectValue else {
            if let array = resultValue.arrayValue {
                records = array.compactMap(EmailDNSRecord.init(jsonValue:))
            } else {
                records = []
            }
            errors = []
            return
        }

        records = Self.decodeRecords(from: object)
        errors = Self.decodeIssues(from: object)
    }

    private static func decodeRecords(from object: [String: JSONValue]) -> [EmailDNSRecord] {
        let candidateArrays = [
            object["records"]?.arrayValue,
            object["record"]?.arrayValue,
            object["dns_records"]?.arrayValue,
            object["items"]?.arrayValue
        ].compactMap { $0 }

        if let firstArray = candidateArrays.first(where: { $0.isEmpty == false }) {
            return firstArray.compactMap(EmailDNSRecord.init(jsonValue:))
        }

        if let nestedObject = object["result"]?.objectValue {
            return decodeRecords(from: nestedObject)
        }

        return []
    }

    private static func decodeIssues(from object: [String: JSONValue]) -> [EmailRoutingDNSIssue] {
        let candidateArrays = [
            object["errors"]?.arrayValue,
            object["issues"]?.arrayValue,
            object["messages"]?.arrayValue
        ].compactMap { $0 }

        if let firstArray = candidateArrays.first(where: { $0.isEmpty == false }) {
            return firstArray.compactMap(EmailRoutingDNSIssue.init(jsonValue:))
        }

        if let nestedObject = object["result"]?.objectValue {
            return decodeIssues(from: nestedObject)
        }

        return []
    }
}

nonisolated struct EmailRoutingDNSIssue: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let message: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let code = try? container.decode(String.self, forKey: AnyCodingKey("code"))
        let message =
            (try? container.decode(String.self, forKey: AnyCodingKey("message"))) ??
            (try? container.decode(String.self, forKey: AnyCodingKey("error"))) ??
            "Email Routing DNS validation failed."
        self.id = code ?? message
        self.message = message
    }

    init?(jsonValue: JSONValue) {
        switch jsonValue {
        case .string(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            id = trimmed
            message = trimmed
        case .object(let object):
            let code = object["code"]?.stringValue ?? object["id"]?.stringValue
            let resolvedMessage =
                object["message"]?.stringValue ??
                object["error"]?.stringValue ??
                object["description"]?.stringValue
            let fallback = code ?? "Email Routing DNS validation failed."
            id = code ?? fallback
            message = resolvedMessage ?? fallback
        default:
            return nil
        }
    }
}

nonisolated struct EmailDNSRecord: Decodable, Hashable, Sendable, Identifiable {
    let type: String
    let name: String
    let content: String
    let ttl: Int?
    let priority: Int?

    var id: String { "\(type):\(name):\(content)" }

    var ttlText: String {
        ttl.map(String.init) ?? "Auto"
    }

    init?(jsonValue: JSONValue) {
        guard let object = jsonValue.objectValue else {
            return nil
        }

        let resolvedType = object["type"]?.stringValue?.uppercased()
        let resolvedName = object["name"]?.stringValue
            ?? object["hostname"]?.stringValue
            ?? object["host"]?.stringValue
        let resolvedContent = object["content"]?.stringValue
            ?? object["value"]?.stringValue
            ?? object["target"]?.stringValue

        guard let resolvedType, let resolvedName, let resolvedContent else {
            return nil
        }

        type = resolvedType
        name = resolvedName
        content = resolvedContent
        ttl = Self.decodeOptionalInt(from: object["ttl"])
        priority = Self.decodeOptionalInt(from: object["priority"])
    }

    private static func decodeOptionalInt(from value: JSONValue?) -> Int? {
        switch value {
        case .number(let number):
            return Int(number)
        case .string(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false,
                  trimmed.localizedCaseInsensitiveCompare("auto") != .orderedSame
            else {
                return nil
            }
            return Int(trimmed)
        default:
            return nil
        }
    }
}

nonisolated struct EmailRoutingRule: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let actions: [EmailRoutingAction]
    let enabled: Bool
    let matchers: [EmailRoutingMatcher]
    let name: String
    let priority: Int?
    let tag: String?

    enum CodingKeys: String, CodingKey {
        case id
        case actions
        case enabled
        case matchers
        case name
        case priority
        case tag
    }

    var forwardAddresses: [String] {
        actions
            .filter { $0.type == "forward" }
            .flatMap(\.stringValues)
    }

    var summaryText: String {
        if forwardAddresses.isEmpty == false {
            return forwardAddresses.joined(separator: ", ")
        }
        if let action = actions.first {
            return action.type.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "No actions configured"
    }

    var matcherSummary: String {
        if matchers.isEmpty {
            return "No matcher configured"
        }

        return matchers.map(\.summaryText).joined(separator: "  ·  ")
    }
}

nonisolated struct EmailRoutingAction: Decodable, Hashable, Sendable {
    let type: String
    let value: JSONValue?

    var stringValues: [String] {
        guard let value else { return [] }
        if let string = value.stringValue {
            return [string]
        }
        if let values = value.arrayValue {
            return values.compactMap(\.stringValue)
        }
        return []
    }
}

nonisolated struct EmailRoutingMatcher: Decodable, Hashable, Sendable {
    let type: String
    let field: String?
    let value: String?

    var summaryText: String {
        if type == "all" {
            return "All unmatched mail"
        }

        let resolvedField = field ?? "value"
        let resolvedValue = value ?? "configured"
        return "\(resolvedField): \(resolvedValue)"
    }
}

nonisolated struct EmailRoutingDestinationAddress: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let created: Date?
    let email: String
    let modified: Date?
    let verified: Date?

    var isVerified: Bool { verified != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case created
        case email
        case modified
        case verified
    }
}

nonisolated struct EmailRoutingDestinationAddressCreateRequest: Encodable, Sendable {
    let email: String
}

nonisolated struct EmailRoutingRuleUpdateRequest: Encodable, Sendable {
    let actions: [EmailRoutingActionUpdate]
    let enabled: Bool
    let matchers: [EmailRoutingMatcherUpdate]
    let name: String
}

nonisolated struct EmailRoutingActionUpdate: Encodable, Sendable {
    let type: String
    let value: [String]
}

nonisolated struct EmailRoutingMatcherUpdate: Encodable, Sendable {
    let type: String
}

nonisolated struct EmailSendingSubdomain: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let created: Date?
    let modified: Date?
    let name: String
    let subdomain: String?
}

extension EmailSendingSubdomain {
    var displayName: String {
        if let subdomain, subdomain.isEmpty == false {
            return subdomain
        }
        return name
    }
}
