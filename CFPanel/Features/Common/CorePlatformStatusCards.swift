import SwiftUI

struct DNSStatusCard: View {
    let summary: DNSInventorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DNS Inventory")
                .font(.headline)

            HStack(spacing: 12) {
                StatusPill(title: "Records", value: summary.totalRecords.formatted())
                StatusPill(title: "Proxied", value: summary.proxiedRecords.formatted())
                StatusPill(title: "Unsupported", value: summary.unsupportedRecords.formatted())
            }

            if summary.topRecordTypes.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Types")
                        .font(.subheadline.weight(.semibold))
                    Text(summary.topRecordTypes.joined(separator: "  ·  "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct PagesStatusCard: View {
    let projects: [PagesProject]
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pages")
                .font(.headline)

            if isRefreshing && projects.isEmpty {
                ProgressView("Loading Pages")
            } else if projects.isEmpty {
                Text(message ?? "No Pages projects found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let healthyCount = projects.filter(\.isDeploymentHealthy).count
                let attentionCount = projects.filter { $0.isDeploymentHealthy == false }.count

                HStack(spacing: 12) {
                    StatusPill(title: "Projects", value: projects.count.formatted())
                    StatusPill(title: "Healthy", value: healthyCount.formatted())
                    StatusPill(title: "Attention", value: attentionCount.formatted())
                }

                ForEach(projects.prefix(3)) { project in
                    NavigationLink(value: PagesProjectRoute(projectID: project.id, destination: .detail)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(project.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(project.latestStatusText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: project.deploymentBadgeText,
                                    tint: pagesBadgeColor(for: project)
                                )
                            }

                            if let deploymentRecencyText = project.deploymentRecencyText {
                                Text("Updated \(deploymentRecencyText)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            if let subdomain = project.subdomain {
                                Text(subdomain)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct WorkersStatusCard: View {
    let runtimes: [WorkerRuntimeSummary]
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workers")
                .font(.headline)

            if isRefreshing && runtimes.isEmpty {
                ProgressView("Loading Workers")
            } else if runtimes.isEmpty {
                Text(message ?? "No Workers scripts found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let publicCount = runtimes.filter(\.hasPublicEndpoint).count
                let detachedCount = runtimes.filter { $0.hasPublicEndpoint == false }.count

                if let message, message.isEmpty == false {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    StatusPill(title: "Scripts", value: runtimes.count.formatted())
                    StatusPill(title: "Public", value: publicCount.formatted())
                    StatusPill(title: "Detached", value: detachedCount.formatted())
                }

                ForEach(runtimes.prefix(3)) { runtime in
                    NavigationLink(value: WorkerRuntimeRoute(scriptID: runtime.id, destination: .detail)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(runtime.script.id)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(runtime.runtimeText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: runtime.endpointBadgeText,
                                    tint: runtime.hasPublicEndpoint ? .green : .orange
                                )
                            }

                            if let activityRecencyText = runtime.activityRecencyText {
                                Text("Updated \(activityRecencyText)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Text(runtime.endpointSummaryText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            if let usageModel = runtime.script.usageModel, usageModel.isEmpty == false {
                                Text(usageModel)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

private func pagesBadgeColor(for project: PagesProject) -> Color {
    if project.isDeploymentFailing {
        return .red
    }
    if project.isDeploymentInProgress {
        return .blue
    }
    if project.isDeploymentHealthy {
        return .green
    }
    return .orange
}

struct RulesStatusCard: View {
    let summary: RulesInventorySummary
    let states: [RulesPhaseState]
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rules")
                .font(.headline)

            if isRefreshing && summary.totalRules == 0 && summary.configuredPhases == 0 {
                ProgressView("Loading Rules")
            } else {
                HStack(spacing: 12) {
                    StatusPill(title: "Phases", value: "\(summary.configuredPhases)/\(summary.totalPhases)")
                    StatusPill(title: "Rules", value: summary.totalRules.formatted())
                    StatusPill(title: "Errors", value: summary.errorPhases.formatted())
                }

                if states.isEmpty {
                    Text("No ruleset phases loaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(states.prefix(3)) { state in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(state.phase.title)
                                        .font(.subheadline.weight(.semibold))

                                    if let ruleset = state.ruleset {
                                        Text("\(ruleset.rules.count) rules · \(ruleset.activeRuleCount) enabled")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    } else if let errorMessage = state.errorMessage {
                                        Text(errorMessage)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Text("Not configured")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer(minLength: 0)

                                runtimeBadge(
                                    title: state.errorMessage != nil ? "Error" : (state.isConfigured ? "Active" : "Idle"),
                                    tint: state.errorMessage != nil ? .red : (state.isConfigured ? .green : .gray)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quinary, in: .rect(cornerRadius: 16))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}
