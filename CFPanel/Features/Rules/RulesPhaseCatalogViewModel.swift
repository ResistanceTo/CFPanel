import Foundation
import Observation

@MainActor
@Observable
final class RulesPhaseCatalogViewModel {
    @ObservationIgnored
    private let store: RulesStore
    @ObservationIgnored
    private let context: RulesWorkspaceContext

    init(store: RulesStore, context: RulesWorkspaceContext) {
        self.store = store
        self.context = context
    }

    var selectedZoneID: String? {
        context.selectedZoneID
    }

    var selectedZone: CloudflareZone? {
        context.selectedZone
    }

    var phaseStates: [RulesPhaseState] {
        store.phaseStates
    }

    var inventorySummary: RulesInventorySummary {
        store.inventorySummary
    }

    var isRefreshing: Bool {
        context.isRefreshingRules
    }

    func state(for phase: CloudflareRulesetPhase) -> RulesPhaseState {
        store.state(for: phase)
    }

    func setState(_ state: RulesPhaseState) {
        store.setState(state)
    }

    func isPhaseLoaded(_ phase: CloudflareRulesetPhase, for zoneID: String) -> Bool {
        context.isPhaseLoaded(phase, for: zoneID)
    }

    func refreshPhase(_ phase: CloudflareRulesetPhase, force: Bool = false) async {
        guard let requestContext = context.makeZoneRequestContext() else {
            setState(RulesPhaseState(phase: phase, ruleset: nil, errorMessage: nil))
            return
        }

        guard force || isPhaseLoaded(phase, for: requestContext.zoneID) == false else { return }

        await context.withRulesLoading {
            do {
                let ruleset = try await context.api.fetchZoneEntryPointRuleset(
                    zoneID: requestContext.zoneID,
                    phase: phase
                )

                guard context.isCurrent(requestContext) else {
                    context.logDebug("Discarded stale rules phase response.")
                    return
                }

                setState(RulesPhaseState(phase: phase, ruleset: ruleset, errorMessage: nil))
                context.markPhaseLoaded(phase, zoneID: requestContext.zoneID)
            } catch {
                guard context.isCurrent(requestContext) else {
                    context.logDebug("Discarded stale rules phase error.")
                    return
                }

                setState(
                    RulesPhaseState(
                        phase: phase,
                        ruleset: nil,
                        errorMessage: error.localizedDescription
                    )
                )
            }
        }
    }
}
