import SwiftUI

struct RulesPhaseDetailView: View {
    @Environment(RulesPhaseCatalogViewModel.self) private var rulesPhaseCatalogViewModel
    @Environment(RulesMutationViewModel.self) private var rulesMutationViewModel
    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false
    let phase: CloudflareRulesetPhase

    @State private var rawJSONPayload: RawJSONPayload?
    @State private var isLoadingPhase = false
    @State private var rulePendingDeletion: RulePendingDeletion?
    @State private var deletionErrorMessage: String?

    var body: some View {
        List {
            Section("Phase") {
                LabeledContent("Name", value: phase.title)
                Text(phase.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isLoadingPhase && state.ruleset == nil && state.errorMessage == nil {
                Section("Status") {
                    ProgressView("Loading Phase Ruleset")
                }
            } else if let deletionErrorMessage {
                Section("Status") {
                    Text(deletionErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else
            if let errorMessage = state.errorMessage {
                Section("Status") {
                    Label("Cloudflare did not return this phase successfully.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let ruleset = state.ruleset {
                Section("Ruleset") {
                    LabeledContent("Name", value: ruleset.name)
                    if let description = ruleset.description, description.isEmpty == false {
                        LabeledContent("Description", value: description)
                    }
                    if let kind = ruleset.kind {
                        LabeledContent("Kind", value: kind.title)
                    }
                    if let version = ruleset.version {
                        LabeledContent("Version", value: version)
                    }
                    LabeledContent("Rules", value: ruleset.rules.count.formatted())
                    LabeledContent("Enabled", value: ruleset.activeRuleCount.formatted())
                    if ruleset.disabledRuleCount > 0 {
                        LabeledContent("Disabled", value: ruleset.disabledRuleCount.formatted())
                    }
                    if let lastUpdated = ruleset.lastUpdated {
                        LabeledContent(
                            "Last Updated",
                            value: lastUpdated.formatted(date: .abbreviated, time: .shortened)
                        )
                    }

                    Button("View Raw Ruleset JSON") {
                        rawJSONPayload = RawJSONPayload(
                            title: "\(phase.title) JSON",
                            body: ruleset.rawJSON
                        )
                    }
                }

                Section("Rules") {
                    if ruleset.rules.isEmpty {
                        Text("This entry point exists, but it has no rules attached.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(ruleset.rules) { rule in
                            let managementContext = RulesRuleManagementContext(
                                    phase: phase,
                                    rulesetID: ruleset.id,
                                    rule: rule
                            )
                            NavigationLink {
                                RulesRuleDetailView(rule: rule, managementContext: managementContext)
                            } label: {
                                RulesRuleRow(rule: rule)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if isAdvancedDangerousModeEnabled {
                                    Button(role: .destructive) {
                                        rulePendingDeletion = RulePendingDeletion(
                                            rulesetID: ruleset.id,
                                            rule: rule
                                        )
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                executedRulesetsSection
            } else {
                Section("Status") {
                    Text("No entry point ruleset is configured for this phase yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(phase.title)
        .navigationBarTitleDisplayMode(.inline)
        .countdownConfirmationDialog(
            "Delete this rule?",
            isPresented: Binding(
                get: { rulePendingDeletion != nil },
                set: { newValue in
                    if newValue == false {
                        rulePendingDeletion = nil
                    }
                }
            ),
            message: ruleDeletionMessage,
            actionTitle: "Delete Rule",
            onCancel: {
                rulePendingDeletion = nil
            }
        ) {
            guard let rulePendingDeletion else { return }
            Task {
                do {
                    try await DangerousActionAuthorizer.authorize(
                        reason: "Confirm deletion of rule \(rulePendingDeletion.rule.displayTitle)."
                    )
                    try await rulesMutationViewModel.deleteZoneRule(
                        phase: phase,
                        rulesetID: rulePendingDeletion.rulesetID,
                        ruleID: rulePendingDeletion.rule.id
                    )
                    self.rulePendingDeletion = nil
                    deletionErrorMessage = nil
                } catch {
                    deletionErrorMessage = error.localizedDescription
                }
            }
        }
        .sheet(item: $rawJSONPayload) { payload in
            RawJSONView(title: payload.title, payload: payload.body)
        }
        .task(id: phase.id) {
            await loadPhaseIfNeeded()
        }
        .refreshable {
            await loadPhase(force: true)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") {
                    Task {
                        await loadPhase(force: true)
                    }
                }
                .disabled(isLoadingPhase || rulesPhaseCatalogViewModel.isRefreshing)
            }
        }
    }

    private var state: RulesPhaseState {
        rulesPhaseCatalogViewModel.state(for: phase)
    }

    @ViewBuilder
    private var executedRulesetsSection: some View {
        let executeRules = state.ruleset?.rules.filter(\.isExecuteAction) ?? []

        if executeRules.isEmpty == false {
            Section("Executed Rulesets") {
                ForEach(executeRules) { rule in
                    if let rulesetID = rule.executedRulesetID {
                        NavigationLink {
                            ReferencedRulesetLoaderView(
                                title: rule.displayTitle,
                                rulesetID: rulesetID
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(rule.displayTitle)
                                            .font(.subheadline.weight(.semibold))
                                        Text(rulesetID.middleEllipsizedToken)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)

                                    RulesBadgeView(
                                        title: "On Demand",
                                        tint: .blue
                                    )
                                }

                                Text("Open this row to load the referenced ruleset only when needed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    private func loadPhaseIfNeeded() async {
        guard let zoneID = rulesPhaseCatalogViewModel.selectedZoneID else { return }
        guard rulesPhaseCatalogViewModel.isPhaseLoaded(phase, for: zoneID) == false else { return }
        await loadPhase()
    }

    private func loadPhase(force: Bool = false) async {
        isLoadingPhase = true
        defer { isLoadingPhase = false }
        await rulesPhaseCatalogViewModel.refreshPhase(phase, force: force)
    }

    private var ruleDeletionMessage: String {
        guard let rule = rulePendingDeletion?.rule else {
            return ""
        }

        let expression = rule.expression?.isEmpty == false ? "\n\(rule.expression ?? "")" : ""
        return "\(rule.displayTitle)\(expression)"
    }
}

private struct RulePendingDeletion {
    let rulesetID: String
    let rule: CloudflareRule
}
