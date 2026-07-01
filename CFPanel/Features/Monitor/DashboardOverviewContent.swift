import SwiftUI

struct DashboardOverviewContent: View {
    @Environment(DashboardHomeViewModel.self) private var dashboardHomeViewModel
    @AppStorage("dashboard_range") private var dashboardRangeRaw: String = DashboardTimeRange.last24Hours.rawValue

    let openRoute: (DashboardRoute) -> Void

    var body: some View {
        List {
            Section {
                if let zone = dashboardHomeViewModel.selectedZone?.name {
                    LabeledContent("Active Site", value: zone)
                } else {
                    LabeledContent("Active Site", value: "No site selected")
                }

                LabeledContent("Workspace Status", value: workspaceStatusTitle)
                LabeledContent("Monitor Window", value: selectedRange.title)

                if let lastRefreshAt = dashboardHomeViewModel.lastRefreshAt {
                    LabeledContent("Last Refresh", value: lastRefreshAt.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                Text("Operational Overview")
            } footer: {
                Text(heroSubtitle)
            }

            Section {
                overviewMetricRow(
                    title: "Requests",
                    value: dashboardHomeViewModel.dashboard.totalRequests.compactAbbreviated,
                    systemImage: "bolt.horizontal.circle"
                )
                overviewMetricRow(
                    title: "Bandwidth",
                    value: dashboardHomeViewModel.dashboard.totalBandwidth.bytesFormatted,
                    systemImage: "arrow.up.arrow.down.circle"
                )
                overviewMetricRow(
                    title: "Visitors",
                    value: dashboardHomeViewModel.dashboard.insights?.uniques.compactAbbreviated ?? "n/a",
                    systemImage: "person.3"
                )
                overviewMetricRow(
                    title: "Threats",
                    value: dashboardHomeViewModel.dashboard.insights?.threats.compactAbbreviated ?? "n/a",
                    systemImage: "shield.lefthalf.filled"
                )
            } header: {
                Text("Overview")
            } footer: {
                Text("Use these headline metrics for a fast check, then open a workflow below when you need more detail.")
            }

            Section {
                quickActionRow(
                    title: DashboardRoute.analytics.title,
                    subtitle: DashboardRoute.analytics.subtitle,
                    systemImage: DashboardRoute.analytics.systemImage,
                    route: .analytics
                )
                quickActionRow(
                    title: DashboardRoute.performance.title,
                    subtitle: DashboardRoute.performance.subtitle,
                    systemImage: DashboardRoute.performance.systemImage,
                    route: .performance
                )
                quickActionRow(
                    title: DashboardRoute.incidentResponse.title,
                    subtitle: DashboardRoute.incidentResponse.subtitle,
                    systemImage: DashboardRoute.incidentResponse.systemImage,
                    route: .incidentResponse
                )
                quickActionRow(
                    title: DashboardRoute.activity.title,
                    subtitle: DashboardRoute.activity.subtitle,
                    systemImage: DashboardRoute.activity.systemImage,
                    route: .activity
                )
            } header: {
                Text("Quick Actions")
            } footer: {
                Text("Jump straight into the workflows you are most likely to need when checking a site.")
            }

            Section {
                LabeledContent("Selected Window", value: selectedRange.title)

                Text(snapshotSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let health = dashboardHomeViewModel.dashboard.health {
                    overviewMetricRow(
                        title: "Error Rate",
                        value: health.errorRate.formatted(.percent.precision(.fractionLength(1))),
                        systemImage: "waveform.badge.exclamationmark"
                    )
                    overviewMetricRow(
                        title: "2xx Responses",
                        value: health.successfulRequests.compactAbbreviated,
                        systemImage: "checkmark.circle"
                    )
                    overviewMetricRow(
                        title: "5xx Responses",
                        value: health.serverErrorRequests.compactAbbreviated,
                        systemImage: "xmark.octagon"
                    )
                } else {
                    Text("Detailed request health becomes available after analytics load for the active site.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Traffic Snapshot")
            } footer: {
                Text("Traffic Snapshot works best as a compact health readout before you drill into Traffic Analytics.")
            }
        }
        .navigationTitle("Monitor")
        .listStyle(.insetGrouped)
    }

    private func quickActionRow(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        systemImage: String,
        route: DashboardRoute
    ) -> some View {
        Button {
            openRoute(route)
        } label: {
            HStack(spacing: 12) {
                CompactNavigationRow(
                    title: title,
                    subtitle: subtitle,
                    systemImage: systemImage
                )

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func overviewMetricRow(
        title: LocalizedStringResource,
        value: String,
        systemImage: String
    ) -> some View {
        LabeledContent {
            Text(value)
                .fontWeight(.semibold)
                .contentTransition(.numericText())
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private var heroSubtitle: String {
        if dashboardHomeViewModel.selectedZone == nil {
            return "Sites owns active site selection. Once a site is selected, Monitor surfaces traffic, performance, and incident tooling here."
        }

        if let lastRefreshAt = dashboardHomeViewModel.lastRefreshAt {
            return "Latest workspace refresh \(lastRefreshAt.formatted(date: .abbreviated, time: .shortened)). Use the cards below to move from status checks into action."
        }

        return "Your active site is ready. Review live health, open analytics, or jump into incident response."
    }

    private var snapshotSummary: String {
        if dashboardHomeViewModel.dashboard.totalRequests == 0 {
            return "No traffic has been loaded yet for the selected window. Pull to refresh or open Traffic Analytics for a deeper look."
        }

        let bandwidth = dashboardHomeViewModel.dashboard.totalBandwidth.bytesFormatted
        let requests = dashboardHomeViewModel.dashboard.totalRequests.compactAbbreviated
        return "\(requests) requests and \(bandwidth) transferred in the \(selectedRange.title.lowercased()) window."
    }

    private var workspaceStatusTitle: String {
        if dashboardHomeViewModel.selectedZone == nil {
            return "Waiting for site selection"
        }

        if dashboardHomeViewModel.isRefreshingDashboard {
            return "Refreshing monitor data"
        }

        return "Ready"
    }

    private var selectedRange: DashboardTimeRange {
        DashboardTimeRange(rawValue: dashboardRangeRaw) ?? .last24Hours
    }
}
