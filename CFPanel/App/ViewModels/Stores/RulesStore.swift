import Foundation
import Observation

@MainActor
@Observable
final class RulesStore {
    var phaseStates = CloudflareRulesetPhase.defaultStates {
        didSet {
            summaryCache.invalidate()
        }
    }

    @ObservationIgnored
    private var summaryCache = RulesInventorySummaryCache()

    var inventorySummary: RulesInventorySummary {
        summaryCache.summary(from: phaseStates)
    }

    func state(for phase: CloudflareRulesetPhase) -> RulesPhaseState {
        phaseStates.first(where: { $0.phase == phase })
            ?? RulesPhaseState(phase: phase, ruleset: nil, errorMessage: nil)
    }

    func setState(_ state: RulesPhaseState) {
        if let index = phaseStates.firstIndex(where: { $0.phase == state.phase }) {
            phaseStates[index] = state
        } else {
            phaseStates.append(state)
            phaseStates.sort { $0.phase.sortOrder < $1.phase.sortOrder }
        }
    }

    func reset() {
        phaseStates = CloudflareRulesetPhase.defaultStates
    }
}
