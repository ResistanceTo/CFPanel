import SwiftUI

struct DashboardTrafficSummarySection: View {
    let zoneName: String?
    let snapshot: DashboardSnapshot
    let selectedRange: DashboardTimeRange

    var body: some View {
        Section {
            if let zoneName {
                LabeledContent("Measured Site", value: zoneName)
            }

            DashboardMetricRow(
                title: "Requests (\(selectedRange.metricTitle))",
                value: snapshot.totalRequests.compactAbbreviated,
                systemImage: "bolt.horizontal.circle"
            )
            DashboardMetricRow(
                title: "Bandwidth (\(selectedRange.metricTitle))",
                value: snapshot.totalBandwidth.bytesFormatted,
                systemImage: "arrow.up.arrow.down.circle"
            )

            if let insights = snapshot.insights {
                DashboardMetricRow(
                    title: "Visitors",
                    value: insights.uniques.compactAbbreviated,
                    systemImage: "person.3"
                )
                DashboardMetricRow(
                    title: "Threats",
                    value: insights.threats.compactAbbreviated,
                    systemImage: "shield.lefthalf.filled"
                )
            }
        } header: {
            Text("Traffic Summary")
        } footer: {
            Text("Site selection is managed in Sites. Token and connection details are managed in Settings.")
        }
    }
}

struct DashboardTrafficPerformanceSection: View {
    var body: some View {
        Section {
            Text("Inspect request volume, traffic quality, cache behavior, and end-user performance.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink(value: DashboardRoute.analytics) {
                CompactNavigationRow(
                    title: "Traffic Analytics",
                    subtitle: "Open 24H, 7D, or 30D trend charts and request health for the active site.",
                    systemImage: "chart.xyaxis.line"
                )
            }

            NavigationLink(value: DashboardRoute.performance) {
                CompactNavigationRow(
                    title: "Performance",
                    subtitle: "Review cache efficiency, audience shape, and content distribution for the active site.",
                    systemImage: "speedometer"
                )
            }
        } header: {
            Text("Traffic & Performance")
        }
    }
}

struct DashboardIncidentResponseSection: View {
    var body: some View {
        Section {
            Text("Open fast operational controls for the active site without leaving Monitor.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink(value: DashboardRoute.incidentResponse) {
                CompactNavigationRow(
                    title: "Incident Response",
                    subtitle: "Toggle Under Attack Mode or purge cache for the active site.",
                    systemImage: "bolt.shield"
                )
            }
        } header: {
            Text("Incident Response")
        }
    }
}

struct DashboardAuditActivitySection: View {
    var body: some View {
        Section {
            Text("Confirm who changed something or trace recent account operations.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink(value: DashboardRoute.activity) {
                CompactNavigationRow(
                    title: "Open Audit Log",
                    subtitle: "Review account-level actions with filters for site scope, actor, and time range.",
                    systemImage: "list.bullet.rectangle"
                )
            }
        } header: {
            Text("Audit & Activity")
        }
    }
}

private struct DashboardMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        LabeledContent {
            Text(value)
                .fontWeight(.semibold)
                .contentTransition(.numericText())
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
