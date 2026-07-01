import SwiftUI

struct RulesRuleRow: View {
    let rule: CloudflareRule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.displayTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(rule.actionTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                RulesBadgeView(title: rule.isEnabled ? "Enabled" : "Disabled", tint: rule.isEnabled ? .green : .orange)
            }

            if let expression = rule.expression, expression.isEmpty == false {
                Text(expression)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let summary = rule.actionParametersSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RulesRuleDetailView: View {
    @Environment(RulesMutationViewModel.self) private var rulesMutationViewModel
    let managementContext: RulesRuleManagementContext?

    @State private var displayedRule: CloudflareRule
    @State private var rawJSONPayload: RawJSONPayload?
    @State private var isPerformingAction = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isConfirmingRuleDisable = false

    init(rule: CloudflareRule, managementContext: RulesRuleManagementContext? = nil) {
        self.managementContext = managementContext
        _displayedRule = State(initialValue: rule)
    }

    var body: some View {
        List {
            Section("Rule") {
                LabeledContent("Action", value: displayedRule.actionTitle)
                LabeledContent("Status", value: displayedRule.isEnabled ? "Enabled" : "Disabled")
                if let ref = displayedRule.ref, ref.isEmpty == false {
                    LabeledContent("Reference", value: ref)
                }
                if let version = displayedRule.version, version.isEmpty == false {
                    LabeledContent("Version", value: version)
                }
                if let categories = displayedRule.categoriesTitle {
                    LabeledContent("Categories", value: categories)
                }
                if let lastUpdated = displayedRule.lastUpdated {
                    LabeledContent(
                        "Last Updated",
                        value: lastUpdated.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }

            if let managementContext {
                Section("Management") {
                    LabeledContent("Phase", value: managementContext.phase.title)

                    Button(displayedRule.isEnabled ? "Disable Rule" : "Enable Rule") {
                        if displayedRule.isEnabled {
                            isConfirmingRuleDisable = true
                            return
                        }

                        Task {
                            await toggleRuleEnabled()
                        }
                    }
                    .disabled(isPerformingAction)
                }
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = displayedRule.description, description.isEmpty == false {
                Section("Description") {
                    Text(description)
                }
            }

            if let expression = displayedRule.expression, expression.isEmpty == false {
                Section("Expression") {
                    Text(expression)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if let actionParameters = displayedRule.actionParameters {
                Section("Action Parameters") {
                    Text(actionParameters.prettyPrintedString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)

                    Button("View Raw Rule JSON") {
                        rawJSONPayload = RawJSONPayload(
                            title: displayedRule.displayTitle,
                            body: displayedRule.rawJSON
                        )
                    }
                }
            } else {
                Section("Raw") {
                    Button("View Raw Rule JSON") {
                        rawJSONPayload = RawJSONPayload(
                            title: displayedRule.displayTitle,
                            body: displayedRule.rawJSON
                        )
                    }
                }
            }
        }
        .navigationTitle(displayedRule.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $rawJSONPayload) { payload in
            RawJSONView(title: payload.title, payload: payload.body)
        }
        .countdownConfirmationDialog(
            "Disable this rule?",
            isPresented: $isConfirmingRuleDisable,
            message: ruleDisableConfirmationMessage,
            actionTitle: "Disable Rule",
            role: .destructive
        ) {
            Task {
                await toggleRuleEnabled()
            }
        }
    }

    private var ruleDisableConfirmationMessage: String {
        let expression = displayedRule.expression?.isEmpty == false
            ? "\n\(displayedRule.expression ?? "")"
            : ""
        return "\(displayedRule.displayTitle)\(expression)"
    }

    private func toggleRuleEnabled() async {
        guard let managementContext else { return }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            if displayedRule.isEnabled {
                try await DangerousActionAuthorizer.authorize(
                    reason: "Confirm disabling rule \(displayedRule.displayTitle)."
                )
            }
            let updatedRule = try await rulesMutationViewModel.updateZoneRuleEnabled(
                phase: managementContext.phase,
                rulesetID: managementContext.rulesetID,
                rule: displayedRule,
                enabled: displayedRule.isEnabled == false
            )
            displayedRule = updatedRule
            errorMessage = nil
            statusMessage = updatedRule.isEnabled ? "Rule enabled." : "Rule disabled."
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }
}

struct ReferencedRulesetDetailView: View {
    let title: String
    let ruleset: CloudflareRuleset

    @State private var rawJSONPayload: RawJSONPayload?

    var body: some View {
        List {
            Section("Ruleset") {
                LabeledContent("Reference", value: title)
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
                        title: ruleset.name,
                        body: ruleset.rawJSON
                    )
                }
            }

            Section("Rules") {
                if ruleset.rules.isEmpty {
                    Text("This referenced ruleset has no rules.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ruleset.rules) { rule in
                        NavigationLink {
                            RulesRuleDetailView(rule: rule)
                        } label: {
                            RulesRuleRow(rule: rule)
                        }
                    }
                }
            }
        }
        .navigationTitle(ruleset.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $rawJSONPayload) { payload in
            RawJSONView(title: payload.title, payload: payload.body)
        }
    }
}

struct ReferencedRulesetLoaderView: View {
    @Environment(RulesetDetailViewModel.self) private var rulesetDetailViewModel
    let title: String
    let rulesetID: String

    @State private var ruleset: CloudflareRuleset?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let ruleset {
                ReferencedRulesetDetailView(title: title, ruleset: ruleset)
            } else {
                List {
                    Section("Reference") {
                        LabeledContent("Title", value: title)
                        LabeledContent("Ruleset ID", value: rulesetID)
                        Text("This page loads the referenced ruleset only after you open it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Status") {
                        if isLoading {
                            ProgressView("Loading Referenced Ruleset")
                        } else if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Ruleset data unavailable.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: rulesetID) {
            await loadRuleset()
        }
        .refreshable {
            await loadRuleset()
        }
    }

    private func loadRuleset() async {
        isLoading = true
        defer { isLoading = false }

        do {
            ruleset = try await rulesetDetailViewModel.loadZoneRuleset(rulesetID: rulesetID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RawJSONPayload: Identifiable {
    let title: String
    let body: String

    var id: String { title + body }
}

struct RawJSONView: View {
    let title: String
    let payload: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(payload)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .textSelection(.enabled)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct RulesBadgeView: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
