import SwiftUI

struct WorkerRuntimeDetailView: View {
    let runtime: WorkerRuntimeSummary

    var body: some View {
        List {
            scriptSection
            reachabilitySection
            menuSection
        }
        .navigationTitle(runtime.script.id)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scriptSection: some View {
        Section("Script") {
            LabeledContent("Script", value: runtime.script.id)
            if let modifiedOn = runtime.script.modifiedOn {
                LabeledContent("Updated", value: modifiedOn.formatted(date: .abbreviated, time: .shortened))
            }
            if let usageModel = runtime.script.usageModel {
                LabeledContent("Usage Model", value: usageModel)
            }
            if let hasAssets = runtime.script.hasAssets {
                LabeledContent("Static Assets", value: hasAssets ? "Attached" : "None")
            }
            if let hasModules = runtime.script.hasModules {
                LabeledContent("Modules", value: hasModules ? "Enabled" : "Disabled")
            }
        }
    }

    private var reachabilitySection: some View {
        Section("Reachability") {
            LabeledContent("Invocation", value: invocationStatus)
            Text(runtime.endpointSummaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let activityRecencyText = runtime.activityRecencyText {
                LabeledContent("Last Activity", value: activityRecencyText)
            }
        }
    }

    private var menuSection: some View {
        Section("Runtime Menus") {
            NavigationLink(value: WorkerRuntimeRoute(scriptID: runtime.id, destination: .exposureManagement)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exposure Management")
                    Text("Load workers.dev state, routes, and custom domains only when you open this page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink(value: WorkerRuntimeRoute(scriptID: runtime.id, destination: .releases)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deployments & Versions")
                    Text("Load deployment history and version metadata without fetching runtime configuration.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink(value: WorkerRuntimeRoute(scriptID: runtime.id, destination: .runtimeConfiguration)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Runtime Configuration")
                    Text("Load bindings, compatibility, observability, and cron triggers on demand.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var invocationStatus: String {
        if runtime.hasPublicEndpoint {
            return "Reachable"
        }
        if runtime.hasScheduledInvocation {
            return "Scheduled"
        }
        return "Detached"
    }
}
