import SwiftUI

struct WorkerRuntimeConfigurationView: View {
    @Environment(WorkerRuntimeConfigurationViewModel.self) private var workerRuntimeConfigurationViewModel
    let runtime: WorkerRuntimeSummary

    @State private var snapshot: WorkerRuntimeConfigurationSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            contextSection
            operationalNotesSection
            runtimeConfigSection
            schedulesSection
            advancedSection
            statusSection
        }
        .navigationTitle("Runtime Config")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: runtime.id) {
            await loadSnapshot()
        }
        .refreshable {
            await loadSnapshot()
        }
    }

    private var contextSection: some View {
        Section("Script") {
            LabeledContent("Script", value: runtime.script.id)
            Text("This page only loads script settings and cron triggers for the current Worker.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var operationalNotesSection: some View {
        if let snapshot, snapshot.operationalNotes.isEmpty == false {
            Section("Operational Notes") {
                ForEach(snapshot.operationalNotes) { note in
                    WorkerOperationalNoteRow(note: note)
                }
            }
        }
    }

    private var runtimeConfigSection: some View {
        Section("Runtime Config") {
            if let settings = snapshot?.settings {
                if let compatibilityDate = settings.compatibilityDate, compatibilityDate.isEmpty == false {
                    LabeledContent("Compatibility Date", value: compatibilityDate)
                }
                if let usageModel = settings.usageModel ?? runtime.script.usageModel,
                   usageModel.isEmpty == false
                {
                    LabeledContent("Usage Model", value: usageModel)
                }
                if let logpush = settings.logpush {
                    LabeledContent("Logpush", value: logpush ? "Enabled" : "Disabled")
                }
                if let tags = settings.tags, tags.isEmpty == false {
                    LabeledContent("Tags", value: tags.joined(separator: ", "))
                }
                if settings.compatibilityFlags?.isEmpty == false {
                    Text(settings.compatibilityFlags?.joined(separator: ", ") ?? "")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if settings.bindingTypeSummary.isEmpty == false {
                    LabeledContent("Bindings", value: settings.bindingTypeSummary.joined(separator: "  ·  "))
                }
                if settings.resolvedBindings.isEmpty == false {
                    ForEach(settings.resolvedBindings) { binding in
                        WorkerBindingRow(binding: binding)
                    }
                }
                if let tailConsumers = settings.tailConsumers, tailConsumers.isEmpty == false {
                    ForEach(tailConsumers) { consumer in
                        WorkerTailConsumerRow(consumer: consumer)
                    }
                }
            } else if isLoading {
                ProgressView("Loading Runtime Config")
            } else {
                Text("Runtime configuration unavailable for this token.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var schedulesSection: some View {
        Section("Cron Triggers") {
            if let snapshot {
                if snapshot.scheduleAvailabilityKnown == false {
                    Text("Cron trigger details unavailable for this token.")
                        .foregroundStyle(.secondary)
                } else if snapshot.resolvedSchedules.isEmpty {
                    Text("No cron triggers configured.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.resolvedSchedules) { schedule in
                        Text(schedule.cron)
                            .font(.system(.footnote, design: .monospaced))
                    }
                }
            } else if isLoading {
                ProgressView("Loading Cron Triggers")
            } else {
                Text("Cron trigger details unavailable.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var advancedSection: some View {
        Section("Advanced") {
            if let limits = snapshot?.settings?.limits {
                WorkerJSONField(title: "Limits", value: limits.prettyPrintedString)
            }
            if let placement = snapshot?.settings?.placement {
                WorkerJSONField(title: "Placement", value: placement.prettyPrintedString)
            }
            if let observability = snapshot?.settings?.observability {
                WorkerJSONField(title: "Observability", value: observability.prettyPrintedString)
            }

            if snapshot?.settings?.limits == nil,
               snapshot?.settings?.placement == nil,
               snapshot?.settings?.observability == nil
            {
                if isLoading {
                    ProgressView("Loading Advanced Config")
                } else {
                    Text("No advanced configuration returned.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let errorMessage {
            Section("Status") {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadSnapshot() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await workerRuntimeConfigurationViewModel.loadWorkerRuntimeConfiguration(scriptName: runtime.script.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
