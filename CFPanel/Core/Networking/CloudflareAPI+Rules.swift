import Foundation

extension CloudflareAPI {
    func fetchZoneEntryPointRuleset(
        zoneID: String,
        phase: CloudflareRulesetPhase
    ) async throws -> CloudflareRuleset? {
        do {
            return try await request(
                path: "/zones/\(zoneID)/rulesets/phases/\(phase.rawValue)/entrypoint"
            )
        } catch CloudflareAPIError.httpStatus(let code, _) where code == 404 {
            return nil
        }
    }

    func fetchZoneRuleset(zoneID: String, rulesetID: String) async throws -> CloudflareRuleset {
        try await request(path: "/zones/\(zoneID)/rulesets/\(rulesetID)")
    }

    func updateZoneRule(
        zoneID: String,
        rulesetID: String,
        ruleID: String,
        payload: JSONValue
    ) async throws -> CloudflareRuleset {
        try await request(
            path: "/zones/\(zoneID)/rulesets/\(rulesetID)/rules/\(ruleID)",
            method: "PATCH",
            body: payload
        )
    }

    func addZoneRule(
        zoneID: String,
        rulesetID: String,
        input: CloudflareRuleInput
    ) async throws -> CloudflareRuleset {
        try await request(
            path: "/zones/\(zoneID)/rulesets/\(rulesetID)/rules",
            method: "POST",
            body: input
        )
    }

    func deleteZoneRule(
        zoneID: String,
        rulesetID: String,
        ruleID: String
    ) async throws {
        try await requestWithoutResult(
            path: "/zones/\(zoneID)/rulesets/\(rulesetID)/rules/\(ruleID)",
            method: "DELETE"
        )
    }
}
