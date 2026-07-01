import SwiftUI

struct RulesCenterView: View {
    @Environment(RulesPhaseCatalogViewModel.self) private var rulesPhaseCatalogViewModel

    private var loadedPhaseCount: Int {
        rulesPhaseCatalogViewModel.phaseStates.filter { $0.ruleset != nil || $0.errorMessage != nil }.count
    }

    var body: some View {
        List {
            summarySection
            protectionRulesSection
            routingRulesSection
        }
        .navigationTitle("Rules & Policies")
    }

    private var summarySection: some View {
        Section("Rules & Policies") {
            if let zone = rulesPhaseCatalogViewModel.selectedZone {
                LabeledContent("Active Site", value: zone.name)
            }

            LabeledContent("Phases", value: CloudflareRulesetPhase.allCases.count.formatted())
            LabeledContent("Loaded", value: loadedPhaseCount.formatted())
            LabeledContent("Pending", value: (CloudflareRulesetPhase.allCases.count - loadedPhaseCount).formatted())

            Text("Open the section that matches the job you are doing. Each rules phase loads its own API response only after you enter it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var protectionRulesSection: some View {
        Section {
            Text("Use these phases when you need to block, challenge, or rate-limit incoming traffic.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(trafficPhases) { phase in
                NavigationLink {
                    RulesPhaseDetailView(phase: phase)
                } label: {
                    RulesPhaseDirectoryRow(state: rulesPhaseCatalogViewModel.state(for: phase))
                }
            }
        } header: {
            Text("Traffic Protection")
        }
    }

    private var routingRulesSection: some View {
        Section {
            Text("Use these phases when you need to steer requests, tune cache behavior, or change origin handling.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(edgeBehaviorPhases) { phase in
                NavigationLink {
                    RulesPhaseDetailView(phase: phase)
                } label: {
                    RulesPhaseDirectoryRow(state: rulesPhaseCatalogViewModel.state(for: phase))
                }
            }
        } header: {
            Text("Routing & Delivery")
        }
    }

    private var trafficPhases: [CloudflareRulesetPhase] {
        [
            .firewallCustom,
            .firewallManaged,
            .rateLimit
        ]
    }

    private var edgeBehaviorPhases: [CloudflareRulesetPhase] {
        [
            .dynamicRedirect,
            .configSettings,
            .origin,
            .cacheSettings
        ]
    }
}

private struct RulesPhaseDirectoryRow: View {
    let state: RulesPhaseState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.phase.systemImage)
                .font(.headline)
                .foregroundStyle(iconTint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 6) {
                Text(state.phase.title)
                    .font(.subheadline.weight(.semibold))
                Text(state.phase.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let ruleset = state.ruleset {
                    Text("\(ruleset.rules.count) rules · \(ruleset.activeRuleCount) enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let errorMessage = state.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Opens a dedicated phase view and loads this ruleset only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            RulesBadgeView(title: badgeTitle, tint: badgeTint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badgeTitle: String {
        if state.errorMessage != nil {
            return "Error"
        }
        if let ruleset = state.ruleset {
            return ruleset.rules.isEmpty ? "Empty" : "Loaded"
        }
        return "On Demand"
    }

    private var badgeTint: Color {
        if state.errorMessage != nil {
            return .red
        }
        if let ruleset = state.ruleset {
            return ruleset.rules.isEmpty ? .orange : .green
        }
        return .blue
    }

    private var iconTint: Color {
        if state.errorMessage != nil {
            return .red
        }
        if state.ruleset != nil {
            return .blue
        }
        return .secondary
    }
}
