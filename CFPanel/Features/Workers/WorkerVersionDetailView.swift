import SwiftUI

struct WorkerVersionDetailView: View {
    @Environment(WorkerVersionsViewModel.self) private var workerVersionsViewModel
    let scriptName: String
    let version: WorkerVersion

    @State private var detail: WorkerVersionDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Version") {
                LabeledContent("Version", value: detail?.versionNumberTitle ?? version.versionNumberTitle)
                LabeledContent {
                    Text(version.id)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("ID")
                }
                if let createdOn = detail?.metadata?.createdOn ?? version.createdOn {
                    LabeledContent("Created", value: createdOn.formatted(date: .abbreviated, time: .shortened))
                }
                if let modifiedOn = detail?.metadata?.modifiedOn ?? version.modifiedOn {
                    LabeledContent("Updated", value: modifiedOn.formatted(date: .abbreviated, time: .shortened))
                }
                if let authorEmail = detail?.metadata?.authorEmail ?? version.metadata?.authorEmail,
                   authorEmail.isEmpty == false
                {
                    LabeledContent("Author", value: authorEmail)
                }
                if let source = detail?.metadata?.source ?? version.metadata?.source,
                   source.isEmpty == false
                {
                    LabeledContent("Source", value: source.replacingOccurrences(of: "_", with: " ").localizedCapitalized)
                }
                if let startupTimeMS = detail?.startupTimeMS {
                    LabeledContent("Startup", value: "\(startupTimeMS) ms")
                }
                if let message = detail?.metadata?.deploymentMessage ?? version.metadata?.deploymentMessage,
                   message.isEmpty == false
                {
                    LabeledContent {
                        Text(message)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(3)
                    } label: {
                        Text("Message")
                    }
                }
                if let triggeredBy = detail?.metadata?.triggeredBy ?? version.metadata?.triggeredBy,
                   triggeredBy.isEmpty == false
                {
                    LabeledContent(
                        "Triggered By",
                        value: triggeredBy.replacingOccurrences(of: "_", with: " ").localizedCapitalized
                    )
                }
            }

            runtimeSection
            bindingsSection
            limitsSection
        }
        .navigationTitle(version.versionNumberTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: version.id) {
            await loadDetail()
        }
        .refreshable {
            await loadDetail()
        }
    }

    @ViewBuilder
    private var runtimeSection: some View {
        Section("Runtime") {
            if let runtime = detail?.resources?.scriptRuntime {
                if let usageModel = runtime.usageModel, usageModel.isEmpty == false {
                    LabeledContent("Usage Model", value: usageModel)
                }
                if let compatibilityDate = runtime.compatibilityDate, compatibilityDate.isEmpty == false {
                    LabeledContent("Compatibility Date", value: compatibilityDate)
                }
                if let flags = runtime.compatibilityFlags, flags.isEmpty == false {
                    Text(flags.joined(separator: ", "))
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            } else if isLoading {
                ProgressView("Loading Runtime")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
            } else {
                Text("Runtime details unavailable.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var bindingsSection: some View {
        Section("Bindings") {
            if let bindings = detail?.resources?.bindings, bindings.isEmpty == false {
                ForEach(bindings) { binding in
                    WorkerBindingRow(binding: binding)
                }
            } else if isLoading {
                ProgressView("Loading Bindings")
            } else {
                Text("No bindings returned for this version.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var limitsSection: some View {
        Section("Advanced") {
            if let limits = detail?.resources?.scriptConfig?.limits {
                WorkerJSONField(title: "Limits", value: limits.prettyPrintedString)
            }
            if let placement = detail?.resources?.scriptConfig?.placement {
                WorkerJSONField(title: "Placement", value: placement.prettyPrintedString)
            }
            if let observability = detail?.resources?.scriptConfig?.observability {
                WorkerJSONField(title: "Observability", value: observability.prettyPrintedString)
            }
            if detail?.resources?.scriptConfig?.limits == nil,
               detail?.resources?.scriptConfig?.placement == nil,
               detail?.resources?.scriptConfig?.observability == nil
            {
                if isLoading {
                    ProgressView("Loading Advanced Config")
                } else {
                    Text("No advanced config returned.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await workerVersionsViewModel.loadWorkerVersionDetail(
                scriptName: scriptName,
                versionID: version.id
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
