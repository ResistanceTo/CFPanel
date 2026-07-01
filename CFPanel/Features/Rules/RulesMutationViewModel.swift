import Foundation
import Observation

@MainActor
@Observable
final class RulesMutationViewModel {
    @ObservationIgnored
    private let catalogViewModel: RulesPhaseCatalogViewModel
    @ObservationIgnored
    private let context: RulesWorkspaceContext

    init(catalogViewModel: RulesPhaseCatalogViewModel, context: RulesWorkspaceContext) {
        self.catalogViewModel = catalogViewModel
        self.context = context
    }

    func updateZoneRuleEnabled(
        phase: CloudflareRulesetPhase,
        rulesetID: String,
        rule: CloudflareRule,
        enabled: Bool
    ) async throws -> CloudflareRule {
        let requestContext = try context.requireZoneRequestContext("Select a zone before updating this rule.")

        return try await context.withRulesLoading {
            let ruleset = try await context.api.updateZoneRule(
                zoneID: requestContext.zoneID,
                rulesetID: rulesetID,
                ruleID: rule.id,
                payload: rule.updatingEnabledPayload(enabled)
            )

            guard context.isCurrent(requestContext) else {
                throw CloudflareAPIError.api(
                    "The active site changed while the rule update was in flight. Refresh and try again."
                )
            }

            catalogViewModel.setState(RulesPhaseState(phase: phase, ruleset: ruleset, errorMessage: nil))
            context.markPhaseLoaded(phase, zoneID: requestContext.zoneID)

            guard let updatedRule = ruleset.rules.first(where: { $0.id == rule.id }) else {
                throw CloudflareAPIError.api(
                    "Cloudflare updated the ruleset, but the modified rule was not returned."
                )
            }

            return updatedRule
        }
    }

    func deleteZoneRule(
        phase: CloudflareRulesetPhase,
        rulesetID: String,
        ruleID: String
    ) async throws {
        let requestContext = try context.requireZoneRequestContext("Select a zone before deleting this rule.")

        try await context.withRulesLoading {
            try await context.api.deleteZoneRule(
                zoneID: requestContext.zoneID,
                rulesetID: rulesetID,
                ruleID: ruleID
            )

            guard context.isCurrent(requestContext) else {
                throw CloudflareAPIError.api(
                    "The active site changed while the rule deletion was in flight. Refresh and try again."
                )
            }

            if let current = catalogViewModel.state(for: phase).ruleset {
                let updated = CloudflareRuleset(
                    id: current.id,
                    name: current.name,
                    description: current.description,
                    kind: current.kind,
                    version: current.version,
                    phase: current.phase,
                    rules: current.rules.filter { $0.id != ruleID },
                    lastUpdated: current.lastUpdated
                )
                catalogViewModel.setState(RulesPhaseState(phase: phase, ruleset: updated, errorMessage: nil))
            }
        }
    }

    func addZoneRule(
        phase: CloudflareRulesetPhase,
        rulesetID: String,
        input: CloudflareRuleInput
    ) async throws {
        let requestContext = try context.requireZoneRequestContext("Select a zone before adding a rule.")

        try await context.withRulesLoading {
            let ruleset = try await context.api.addZoneRule(
                zoneID: requestContext.zoneID,
                rulesetID: rulesetID,
                input: input
            )

            guard context.isCurrent(requestContext) else {
                throw CloudflareAPIError.api(
                    "The active site changed while adding the rule. Refresh and try again."
                )
            }

            catalogViewModel.setState(RulesPhaseState(phase: phase, ruleset: ruleset, errorMessage: nil))
            context.markPhaseLoaded(phase, zoneID: requestContext.zoneID)
        }
    }
}
