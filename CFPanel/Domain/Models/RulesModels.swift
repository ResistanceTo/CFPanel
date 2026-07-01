import Foundation
import SwiftUI

nonisolated enum CloudflareRulesetPhase: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case dynamicRedirect = "http_request_dynamic_redirect"
    case configSettings = "http_config_settings"
    case origin = "http_request_origin"
    case firewallCustom = "http_request_firewall_custom"
    case rateLimit = "http_ratelimit"
    case cacheSettings = "http_request_cache_settings"
    case firewallManaged = "http_request_firewall_managed"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dynamicRedirect:
            "Single Redirects"
        case .configSettings:
            "Configuration Rules"
        case .origin:
            "Origin Rules"
        case .firewallCustom:
            "Custom WAF Rules"
        case .rateLimit:
            "Rate Limiting"
        case .cacheSettings:
            "Cache Rules"
        case .firewallManaged:
            "Managed WAF"
        }
    }

    var subtitle: String {
        switch self {
        case .dynamicRedirect:
            "Review zone-level redirect logic executed before request handling continues."
        case .configSettings:
            "Inspect per-request config changes such as security level and feature toggles."
        case .origin:
            "See origin steering, host header, and resolve overrides applied at the edge."
        case .firewallCustom:
            "Audit custom WAF expressions that allow, block, skip, or challenge traffic."
        case .rateLimit:
            "Review rules that throttle abusive traffic before it reaches the origin."
        case .cacheSettings:
            "Inspect cache eligibility, TTL, and cache-key behavior configured by rule."
        case .firewallManaged:
            "See managed WAF deployments and overrides attached to the zone entry point."
        }
    }

    var systemImage: String {
        switch self {
        case .dynamicRedirect:
            "arrow.trianglehead.branch"
        case .configSettings:
            "switch.2"
        case .origin:
            "point.3.connected.trianglepath.dotted"
        case .firewallCustom:
            "shield.lefthalf.filled"
        case .rateLimit:
            "speedometer"
        case .cacheSettings:
            "externaldrive.badge.checkmark"
        case .firewallManaged:
            "lock.shield"
        }
    }

    var sortOrder: Int {
        switch self {
        case .dynamicRedirect: 0
        case .configSettings: 1
        case .origin: 2
        case .firewallCustom: 3
        case .rateLimit: 4
        case .cacheSettings: 5
        case .firewallManaged: 6
        }
    }
}

nonisolated enum CloudflareRulesetKind: String, Codable, Hashable, Sendable {
    case root
    case zone
    case managed
    case custom

    var title: String {
        switch self {
        case .root:
            "Root"
        case .zone:
            "Zone"
        case .managed:
            "Managed"
        case .custom:
            "Custom"
        }
    }
}

nonisolated struct CloudflareRule: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let version: String?
    let ref: String?
    let description: String?
    let action: String
    let actionParameters: JSONValue?
    let categories: [String]?
    let expression: String?
    let lastUpdated: Date?
    let enabled: Bool?
    let additionalFields: [String: JSONValue]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        id = try container.decode(String.self, forKey: AnyCodingKey("id"))
        version = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("version"))
        ref = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("ref"))
        description = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("description"))
        action = try container.decode(String.self, forKey: AnyCodingKey("action"))
        actionParameters = try container.decodeIfPresent(JSONValue.self, forKey: AnyCodingKey("action_parameters"))
        categories = try container.decodeIfPresent([String].self, forKey: AnyCodingKey("categories"))
        expression = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("expression"))
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: AnyCodingKey("last_updated"))
        enabled = try container.decodeIfPresent(Bool.self, forKey: AnyCodingKey("enabled"))

        var capturedFields: [String: JSONValue] = [:]
        for key in container.allKeys where Self.knownFieldNames.contains(key.stringValue) == false {
            capturedFields[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        additionalFields = capturedFields
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)

        try container.encode(id, forKey: AnyCodingKey("id"))
        try container.encodeIfPresent(version, forKey: AnyCodingKey("version"))
        try container.encodeIfPresent(ref, forKey: AnyCodingKey("ref"))
        try container.encodeIfPresent(description, forKey: AnyCodingKey("description"))
        try container.encode(action, forKey: AnyCodingKey("action"))
        try container.encodeIfPresent(actionParameters, forKey: AnyCodingKey("action_parameters"))
        try container.encodeIfPresent(categories, forKey: AnyCodingKey("categories"))
        try container.encodeIfPresent(expression, forKey: AnyCodingKey("expression"))
        try container.encodeIfPresent(lastUpdated, forKey: AnyCodingKey("last_updated"))
        try container.encodeIfPresent(enabled, forKey: AnyCodingKey("enabled"))

        for key in additionalFields.keys.sorted() {
            guard let value = additionalFields[key] else { continue }
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }

    var isEnabled: Bool {
        enabled ?? true
    }

    var displayTitle: String {
        if let description, description.isEmpty == false {
            return description
        }
        if let ref, ref.isEmpty == false {
            return ref
        }
        return actionTitle
    }

    var actionTitle: String {
        action
            .replacingOccurrences(of: "_", with: " ")
            .localizedCapitalized
    }

    var categoriesTitle: String? {
        guard let categories, categories.isEmpty == false else { return nil }
        return categories.joined(separator: " · ")
    }

    var actionParametersSummary: String? {
        guard let actionParameters else { return nil }

        switch actionParameters {
        case .object(let object):
            if let id = object["id"]?.stringValue {
                return "Target ruleset \(id.middleEllipsizedToken)"
            }
            if object.isEmpty {
                return "No parameters"
            }
            return object.keys.sorted().joined(separator: ", ")
        case .array(let values):
            return values.isEmpty ? "No parameters" : "\(values.count) parameter values"
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

    var isExecuteAction: Bool {
        action == "execute"
    }

    var executedRulesetID: String? {
        guard
            isExecuteAction,
            let actionParameters,
            case .object(let object) = actionParameters,
            let id = object["id"]?.stringValue,
            id.isEmpty == false
        else {
            return nil
        }

        return id
    }

    var rawJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(self),
              let value = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return value
    }

    func updatingEnabledPayload(_ enabled: Bool) -> JSONValue {
        var payload = mutableFieldPayload
        payload["enabled"] = .bool(enabled)
        return .object(payload)
    }

    private var mutableFieldPayload: [String: JSONValue] {
        var payload = additionalFields
        payload["action"] = .string(action)

        if let ref {
            payload["ref"] = .string(ref)
        } else {
            payload.removeValue(forKey: "ref")
        }

        if let description {
            payload["description"] = .string(description)
        } else {
            payload.removeValue(forKey: "description")
        }

        if let actionParameters {
            payload["action_parameters"] = actionParameters
        } else {
            payload.removeValue(forKey: "action_parameters")
        }

        if let expression {
            payload["expression"] = .string(expression)
        } else {
            payload.removeValue(forKey: "expression")
        }

        payload.removeValue(forKey: "id")
        payload.removeValue(forKey: "version")
        payload.removeValue(forKey: "last_updated")
        payload.removeValue(forKey: "categories")

        return payload
    }

    private static let knownFieldNames: Set<String> = [
        "id",
        "version",
        "ref",
        "description",
        "action",
        "action_parameters",
        "categories",
        "expression",
        "last_updated",
        "enabled"
    ]
}

nonisolated struct RulesRuleManagementContext: Identifiable, Hashable, Sendable {
    let phase: CloudflareRulesetPhase
    let rulesetID: String
    let rule: CloudflareRule

    var id: String {
        "\(phase.rawValue):\(rulesetID):\(rule.id)"
    }
}

nonisolated struct CloudflareRuleset: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let kind: CloudflareRulesetKind?
    let version: String?
    let phase: CloudflareRulesetPhase?
    let rules: [CloudflareRule]
    let lastUpdated: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case kind
        case version
        case phase
        case rules
        case lastUpdated = "last_updated"
    }

    var activeRuleCount: Int {
        rules.filter(\.isEnabled).count
    }

    var disabledRuleCount: Int {
        rules.filter { $0.isEnabled == false }.count
    }

    var executeRuleCount: Int {
        rules.filter { $0.action == "execute" }.count
    }

    var rawJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(self),
              let value = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return value
    }
}

nonisolated struct RulesPhaseState: Identifiable, Equatable, Sendable {
    let phase: CloudflareRulesetPhase
    var ruleset: CloudflareRuleset?
    var errorMessage: String?

    var id: String { phase.id }

    var isConfigured: Bool {
        ruleset != nil
    }
}

nonisolated struct RulesInventorySummary: Equatable, Sendable {
    let configuredPhases: Int
    let totalPhases: Int
    let totalRules: Int
    let disabledRules: Int
    let executeRules: Int
    let errorPhases: Int

    static let empty = RulesInventorySummary(
        configuredPhases: 0,
        totalPhases: CloudflareRulesetPhase.allCases.count,
        totalRules: 0,
        disabledRules: 0,
        executeRules: 0,
        errorPhases: 0
    )
}

nonisolated struct CloudflareRuleInput: Encodable, Sendable {
    let action: String
    let expression: String
    let description: String?
    let enabled: Bool?
    let actionParameters: JSONValue?

    enum CodingKeys: String, CodingKey {
        case action, expression, description, enabled
        case actionParameters = "action_parameters"
    }
}
