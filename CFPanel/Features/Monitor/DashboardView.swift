import Charts
import SwiftUI

struct DashboardView: View {
    @Environment(DashboardHomeViewModel.self) private var dashboardHomeViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("dashboard_range") private var dashboardRangeRaw: String = DashboardTimeRange.last24Hours.rawValue
    @State private var path: [DashboardRoute] = []
    @State private var selectedRoute: DashboardRoute? = .overview

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
    }

    private var compactLayout: some View {
        NavigationStack(path: $path) {
            dashboardHome
                .task(id: dashboardLoadKey) {
                    await loadDashboardIfNeeded()
                }
                .refreshable {
                    await refreshDashboard(force: true)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Refresh", action: refreshButtonTapped)
                            .disabled(dashboardHomeViewModel.isRefreshingDashboard)
                    }
                }
                .navigationDestination(for: DashboardRoute.self) { route in
                    destinationView(for: route)
                }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: $selectedRoute) {
                workspaceSection
            }
            .navigationTitle("Monitor")
            .navigationSplitViewColumnWidth(min: 320, ideal: 360)
            .task(id: dashboardLoadKey) {
                await loadDashboardIfNeeded()
            }
            .refreshable {
                await refreshDashboard(force: true)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", action: refreshButtonTapped)
                        .disabled(dashboardHomeViewModel.isRefreshingDashboard)
                }
            }
        } detail: {
            NavigationStack {
                if let selectedRoute {
                    destinationView(for: selectedRoute)
                } else {
                    ContentUnavailableView(
                        "Select a Monitor Tool",
                        systemImage: "waveform.path.ecg",
                        description: Text("Choose an analytics or incident workflow from the sidebar.")
                    )
                }
            }
        }
    }

    private var dashboardHome: some View {
        DashboardOverviewContent { route in
            open(route)
        }
    }

    private var workspaceSection: some View {
        Section("Monitor Tools") {
            ForEach(DashboardRoute.allCases) { route in
                NavigationLink(value: route) {
                    CompactNavigationRow(
                        title: route.title,
                        subtitle: route.subtitle,
                        systemImage: route.systemImage
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: DashboardRoute) -> some View {
        switch route {
        case .overview:
            dashboardHome
        case .analytics:
            DashboardAnalyticsDetailView()
        case .performance:
            DashboardPerformanceDetailView()
        case .activity:
            DashboardActivityView()
        case .incidentResponse:
            PanicCenterView()
        }
    }

    private func loadDashboardIfNeeded() async {
        guard let zoneID = dashboardHomeViewModel.selectedZoneID else { return }
        guard dashboardHomeViewModel.isDashboardLoaded(for: zoneID, range: selectedRange) == false else { return }
        await refreshDashboard(force: false)
    }

    private func refreshDashboard(force: Bool) async {
        do {
            try await dashboardHomeViewModel.refreshHome(range: selectedRange, force: force)
        } catch {
            dashboardHomeViewModel.presentError(error)
        }
    }

    private func refreshButtonTapped() {
        Task {
            await refreshDashboard(force: true)
        }
    }

    private func open(_ route: DashboardRoute) {
        Task { @MainActor in
            if horizontalSizeClass == .regular {
                selectedRoute = route
            } else {
                path.append(route)
            }
        }
    }

    private var dashboardLoadKey: String {
        "\(dashboardHomeViewModel.selectedZoneID ?? ""):\(selectedRange.rawValue)"
    }

    private var selectedRange: DashboardTimeRange {
        DashboardTimeRange(rawValue: dashboardRangeRaw) ?? .last24Hours
    }
}

enum DashboardRoute: Hashable {
    case overview
    case analytics
    case performance
    case activity
    case incidentResponse
}

extension DashboardRoute: CaseIterable, Identifiable {
    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .overview: "Overview"
        case .analytics: "Traffic Analytics"
        case .performance: "Performance"
        case .activity: "Audit Log"
        case .incidentResponse: "Incident Response"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .overview:
            "Start from the current site snapshot, then branch into analytics, performance, or incident handling."
        case .analytics:
            "Open 24H, 7D, or 30D trend charts and request health for the active site."
        case .performance:
            "Review cache efficiency, audience shape, and content distribution for the active site."
        case .activity:
            "Review account-level actions with filters for site scope, actor, and time range."
        case .incidentResponse:
            "Toggle Under Attack Mode or purge cache for the active site."
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .analytics: "chart.xyaxis.line"
        case .performance: "speedometer"
        case .activity: "list.bullet.rectangle"
        case .incidentResponse: "bolt.shield"
        }
    }
}

private struct DashboardAnalyticsDetailView: View {
    @Environment(DashboardHomeViewModel.self) private var dashboardHomeViewModel
    @AppStorage("dashboard_range") private var dashboardRangeRaw: String = DashboardTimeRange.last24Hours.rawValue
    @AppStorage("dashboard_trend_metric") private var trendMetricRaw: String = DashboardTrendMetric.requests.rawValue
    @State private var selectedTrafficDate: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                analyticsControlCard
                chartCard
                TrafficHealthCard(
                    health: dashboardHomeViewModel.dashboard.health,
                    isRefreshing: dashboardHomeViewModel.isRefreshingDashboard,
                    hasTraffic: dashboardHomeViewModel.dashboard.totalRequests > 0
                )
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Traffic Analytics")
        .task(id: dashboardLoadKey) {
            guard let zoneID = dashboardHomeViewModel.selectedZoneID else { return }
            guard dashboardHomeViewModel.isDashboardLoaded(for: zoneID, range: selectedRange) == false else { return }
            do {
                try await dashboardHomeViewModel.refresh(range: selectedRange)
            } catch {
                dashboardHomeViewModel.presentError(error)
            }
        }
        .refreshable {
            do {
                try await dashboardHomeViewModel.refresh(range: selectedRange)
            } catch {
                dashboardHomeViewModel.presentError(error)
            }
        }
    }

    private var dashboardLoadKey: String {
        "\(dashboardHomeViewModel.selectedZoneID ?? ""):\(selectedRange.rawValue):analytics"
    }

    private var selectedRange: DashboardTimeRange {
        DashboardTimeRange(rawValue: dashboardRangeRaw) ?? .last24Hours
    }

    private var selectedTrendMetric: DashboardTrendMetric {
        DashboardTrendMetric(rawValue: trendMetricRaw) ?? .requests
    }

    private var analyticsControlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics Controls")
                .font(.headline)
            Text("Filters stay here so the top-level Monitor view remains a compact summary page.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Picker("Range", selection: $dashboardRangeRaw) {
                    ForEach(DashboardTimeRange.allCases) { range in
                        Text(range.title).tag(range.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Metric", selection: $trendMetricRaw) {
                    ForEach(DashboardTrendMetric.allCases) { metric in
                        Text(metric.title).tag(metric.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Traffic Trend")
                        .font(.headline)
                    Text(selectedRange.usesHourlyBuckets ? "Hourly trend for the active zone." : "Daily trend for the active zone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if dashboardHomeViewModel.isRefreshingDashboard && dashboardHomeViewModel.dashboard.timeseries.isEmpty {
                ProgressView("Loading Analytics")
                    .frame(maxWidth: .infinity, minHeight: 280)
            } else if dashboardHomeViewModel.dashboard.timeseries.isEmpty {
                ContentUnavailableView("No Analytics Yet", systemImage: "chart.xyaxis.line")
            } else {
                dashboardTrendSummary

                Chart(dashboardHomeViewModel.dashboard.timeseries) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(selectedTrendMetric.title, chartValue(for: point))
                    )
                    .foregroundStyle(chartTint.opacity(0.16))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(selectedTrendMetric.title, chartValue(for: point))
                    )
                    .foregroundStyle(chartTint)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    if point.id == peakPoint?.id {
                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value(selectedTrendMetric.title, chartValue(for: point))
                        )
                        .foregroundStyle(chartTint)
                        .symbolSize(60)
                        .annotation(position: .top) {
                            Text(peakPointTitle)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.background, in: Capsule())
                        }
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("Selected", selectedPoint.timestamp))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                selectedPointAnnotation(for: selectedPoint)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: selectedRange.usesHourlyBuckets ? 6 : 7)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(axisLabel(for: date))
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedTrafficDate)
                .frame(height: 280)
                .animation(.snappy, value: selectedTrendMetric)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var dashboardTrendSummary: some View {
        HStack(spacing: 12) {
            trendPill(
                title: "Peak",
                value: peakPointTitle,
                tint: chartTint
            )
            trendPill(
                title: "Average",
                value: averagePointTitle,
                tint: .secondary
            )
            trendPill(
                title: "Window",
                value: selectedRange.title,
                tint: .secondary
            )
        }
    }

    private var chartTint: Color {
        selectedTrendMetric == .requests ? .blue : .teal
    }

    private var peakPoint: TrafficPoint? {
        dashboardHomeViewModel.dashboard.timeseries.max { lhs, rhs in
            chartValue(for: lhs) < chartValue(for: rhs)
        }
    }

    private var selectedPoint: TrafficPoint? {
        guard let selectedTrafficDate else { return nil }
        return dashboardHomeViewModel.dashboard.timeseries.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(selectedTrafficDate))
                < abs(rhs.timestamp.timeIntervalSince(selectedTrafficDate))
        }
    }

    private var peakPointTitle: String {
        guard let peakPoint else { return "n/a" }
        return selectedTrendMetric == .requests
            ? peakPoint.requests.compactAbbreviated
            : peakPoint.bandwidth.bytesFormatted
    }

    private var averagePointTitle: String {
        let points = dashboardHomeViewModel.dashboard.timeseries
        guard points.isEmpty == false else { return "n/a" }

        switch selectedTrendMetric {
        case .requests:
            let average = Double(points.reduce(0) { $0 + $1.requests }) / Double(points.count)
            return Int(average.rounded()).compactAbbreviated
        case .bandwidth:
            let average = points.reduce(Int64(0)) { $0 + $1.bandwidth } / Int64(points.count)
            return average.bytesFormatted
        }
    }

    private func chartValue(for point: TrafficPoint) -> Double {
        switch selectedTrendMetric {
        case .requests:
            return Double(point.requests)
        case .bandwidth:
            return Double(point.bandwidth)
        }
    }

    private func axisLabel(for date: Date) -> String {
        if selectedRange.usesHourlyBuckets {
            return date.formatted(.dateTime.hour())
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func trendPill(title: LocalizedStringResource, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quinary, in: .rect(cornerRadius: 16))
    }

    private func selectedPointAnnotation(for point: TrafficPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(axisLabel(for: point.timestamp))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(selectedTrendMetric == .requests ? point.requests.compactAbbreviated : point.bandwidth.bytesFormatted)
                .font(.caption.weight(.semibold))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }
}

private struct DashboardPerformanceDetailView: View {
    @Environment(DashboardHomeViewModel.self) private var dashboardHomeViewModel
    @AppStorage("dashboard_range") private var dashboardRangeRaw: String = DashboardTimeRange.last24Hours.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                controlsCard
                TrafficEfficiencyCard(
                    insights: dashboardHomeViewModel.dashboard.insights,
                    isRefreshing: dashboardHomeViewModel.isRefreshingDashboard,
                    hasTraffic: dashboardHomeViewModel.dashboard.totalRequests > 0
                )
                TrafficProfileCard(
                    insights: dashboardHomeViewModel.dashboard.insights,
                    isRefreshing: dashboardHomeViewModel.isRefreshingDashboard,
                    hasTraffic: dashboardHomeViewModel.dashboard.totalRequests > 0
                )
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Performance")
        .task(id: dashboardLoadKey) {
            guard let zoneID = dashboardHomeViewModel.selectedZoneID else { return }
            guard dashboardHomeViewModel.isDashboardLoaded(for: zoneID, range: selectedRange) == false else { return }
            do {
                try await dashboardHomeViewModel.refresh(range: selectedRange)
            } catch {
                dashboardHomeViewModel.presentError(error)
            }
        }
        .refreshable {
            do {
                try await dashboardHomeViewModel.refresh(range: selectedRange)
            } catch {
                dashboardHomeViewModel.presentError(error)
            }
        }
    }

    private var dashboardLoadKey: String {
        "\(dashboardHomeViewModel.selectedZoneID ?? ""):\(selectedRange.rawValue):performance"
    }

    private var selectedRange: DashboardTimeRange {
        DashboardTimeRange(rawValue: dashboardRangeRaw) ?? .last24Hours
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Window")
                .font(.headline)
            Text("Use the same analytics range here to inspect cache efficiency and content distribution without opening the traffic trend page.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Range", selection: $dashboardRangeRaw) {
                ForEach(DashboardTimeRange.allCases) { range in
                    Text(range.title).tag(range.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}
