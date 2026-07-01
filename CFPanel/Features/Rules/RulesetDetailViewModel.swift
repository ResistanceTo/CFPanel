import Foundation
import Observation

@MainActor
@Observable
final class RulesetDetailViewModel {
    @ObservationIgnored
    private let context: RulesWorkspaceContext

    init(context: RulesWorkspaceContext) {
        self.context = context
    }

    func loadZoneRuleset(rulesetID: String) async throws -> CloudflareRuleset {
        let zoneID = try context.requireSelectedZoneID("Select a zone before opening ruleset details.")
        return try await context.api.fetchZoneRuleset(zoneID: zoneID, rulesetID: rulesetID)
    }
}
