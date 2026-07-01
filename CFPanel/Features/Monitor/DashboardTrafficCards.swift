import Charts
import SwiftUI

struct TrafficHealthCard: View {
    let health: TrafficHealthSnapshot?
    let isRefreshing: Bool
    let hasTraffic: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Request Health")
                    .font(.headline)

                Spacer(minLength: 0)

                if let health {
                    Text(health.totalRequests.compactAbbreviated)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            if isRefreshing && health == nil && hasTraffic == false {
                ProgressView("Loading Request Health")
            } else if let health {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: health.errorRate > 0.05 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(health.errorRate > 0.05 ? .orange : .green)
                            .accessibilityHidden(true)
                        Text(health.errorRate, format: .percent.precision(.fractionLength(1)))
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(health.errorRate > 0.05 ? .orange : .green)
                            .accessibilityLabel("Error rate")
                        Text("error rate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(health.totalRequests.compactAbbreviated) classified requests in the selected window")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                ViewThatFits {
                    HStack(spacing: 12) {
                        healthPill(title: "2xx", value: health.successfulRequests, tint: .green, systemImage: "checkmark.circle.fill")
                        healthPill(title: "3xx", value: health.redirectedRequests, tint: .blue, systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        healthPill(title: "4xx", value: health.clientErrorRequests, tint: .orange, systemImage: "exclamationmark.triangle.fill")
                        healthPill(title: "5xx", value: health.serverErrorRequests, tint: .red, systemImage: "xmark.octagon.fill")
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            healthPill(title: "2xx", value: health.successfulRequests, tint: .green, systemImage: "checkmark.circle.fill")
                            healthPill(title: "3xx", value: health.redirectedRequests, tint: .blue, systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        }

                        HStack(spacing: 12) {
                            healthPill(title: "4xx", value: health.clientErrorRequests, tint: .orange, systemImage: "exclamationmark.triangle.fill")
                            healthPill(title: "5xx", value: health.serverErrorRequests, tint: .red, systemImage: "xmark.octagon.fill")
                        }
                    }
                }

                if health.statusBreakdown.isEmpty == false {
                    Chart(health.statusBreakdown) { bucket in
                        BarMark(
                            x: .value("Requests", bucket.requests),
                            y: .value("Status", "\(bucket.code)")
                        )
                        .foregroundStyle(statusColor(for: bucket.code))
                        .accessibilityLabel(statusDescription(for: bucket.code))
                        .accessibilityValue(bucket.requests.formatted())
                        .cornerRadius(8)
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 220)
                }
            } else {
                Text("Status code analytics unavailable for this zone or token.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private func healthPill(title: LocalizedStringResource, value: Int, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(value.compactAbbreviated)
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: 16))
    }

    private func statusColor(for code: Int) -> Color {
        switch code {
        case 200 ..< 300:
            .green
        case 300 ..< 400:
            .blue
        case 400 ..< 500:
            .orange
        case 500 ..< 600:
            .red
        default:
            .gray
        }
    }

    private func statusDescription(for code: Int) -> String {
        switch code {
        case 200 ..< 300:
            "Successful HTTP \(code)"
        case 300 ..< 400:
            "Redirect HTTP \(code)"
        case 400 ..< 500:
            "Client error HTTP \(code)"
        case 500 ..< 600:
            "Server error HTTP \(code)"
        default:
            "HTTP \(code)"
        }
    }
}

struct TrafficEfficiencyCard: View {
    let insights: TrafficInsightsSnapshot?
    let isRefreshing: Bool
    let hasTraffic: Bool

    private var requestSlices: [CacheSlice] {
        guard let insights else { return [] }
        return [
            CacheSlice(label: "Cached", value: Double(max(insights.cachedRequests, 0)), tint: .green),
            CacheSlice(label: "Uncached", value: Double(max(insights.uncachedRequests, 0)), tint: .orange)
        ]
    }

    private var bandwidthSlices: [CacheSlice] {
        guard let insights else { return [] }
        return [
            CacheSlice(label: "Cached", value: Double(max(insights.cachedBandwidth, 0)), tint: .teal),
            CacheSlice(label: "Uncached", value: Double(max(insights.uncachedBandwidth, 0)), tint: .purple)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cache Efficiency")
                    .font(.headline)

                Spacer(minLength: 0)

                if let insights {
                    Text(insights.cachedRequests.compactAbbreviated)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            if isRefreshing && insights == nil && hasTraffic == false {
                ProgressView("Loading Cache Analytics")
            } else if let insights {
                ViewThatFits {
                    HStack(spacing: 12) {
                        percentagePill(
                            title: "Req Cache",
                            value: insights.cacheHitRate,
                            tint: insights.cacheHitRate > 0.5 ? .green : .orange
                        )
                        percentagePill(
                            title: "Byte Cache",
                            value: insights.bandwidthCacheHitRate,
                            tint: insights.bandwidthCacheHitRate > 0.5 ? .teal : .purple
                        )
                    }

                    VStack(spacing: 12) {
                        percentagePill(
                            title: "Req Cache",
                            value: insights.cacheHitRate,
                            tint: insights.cacheHitRate > 0.5 ? .green : .orange
                        )
                        percentagePill(
                            title: "Byte Cache",
                            value: insights.bandwidthCacheHitRate,
                            tint: insights.bandwidthCacheHitRate > 0.5 ? .teal : .purple
                        )
                    }
                }

                ViewThatFits {
                    HStack(alignment: .top, spacing: 16) {
                        cacheDonutChart(
                            title: "Requests",
                            slices: requestSlices,
                            centerValue: insights.cachedRequests.compactAbbreviated
                        )

                        cacheDonutChart(
                            title: "Bandwidth",
                            slices: bandwidthSlices,
                            centerValue: insights.cachedBandwidth.bytesFormatted
                        )
                    }

                    VStack(spacing: 16) {
                        cacheDonutChart(
                            title: "Requests",
                            slices: requestSlices,
                            centerValue: insights.cachedRequests.compactAbbreviated
                        )

                        cacheDonutChart(
                            title: "Bandwidth",
                            slices: bandwidthSlices,
                            centerValue: insights.cachedBandwidth.bytesFormatted
                        )
                    }
                }

                ViewThatFits {
                    HStack(spacing: 12) {
                        metricPill(title: "Visitors", value: insights.uniques.compactAbbreviated)
                        metricPill(title: "Page Views", value: insights.pageViews.compactAbbreviated)
                        metricPill(title: "Threats", value: insights.threats.compactAbbreviated)
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            metricPill(title: "Visitors", value: insights.uniques.compactAbbreviated)
                            metricPill(title: "Page Views", value: insights.pageViews.compactAbbreviated)
                        }

                        metricPill(title: "Threats", value: insights.threats.compactAbbreviated)
                    }
                }
            } else {
                Text("Cache and audience analytics unavailable for this zone or token.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private func metricPill(title: LocalizedStringResource, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quinary, in: .rect(cornerRadius: 16))
    }

    private func percentagePill(title: LocalizedStringResource, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value, format: .percent.precision(.fractionLength(1)))
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: 16))
    }

    private func cacheDonutChart(title: String, slices: [CacheSlice], centerValue: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Value", slice.value),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .foregroundStyle(slice.tint)
                .cornerRadius(6)
            }
            .chartLegend(position: .bottom, spacing: 12)
            .frame(height: 170)
            .overlay {
                VStack(spacing: 2) {
                    Text("Cached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(centerValue)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrafficProfileCard: View {
    let insights: TrafficInsightsSnapshot?
    let isRefreshing: Bool
    let hasTraffic: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Traffic Profile")
                    .font(.headline)

                Spacer(minLength: 0)

                if let insights {
                    Text(insights.uniques.compactAbbreviated)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if isRefreshing && insights == nil && hasTraffic == false {
                ProgressView("Loading Traffic Profile")
            } else if let insights {
                if insights.topCountries.isEmpty && insights.topContentTypes.isEmpty {
                    Text("No country or content-type breakdown available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if insights.topCountries.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Top Countries")
                                .font(.subheadline.weight(.semibold))

                            Chart(insights.topCountries) { bucket in
                                BarMark(
                                    x: .value("Requests", bucket.requests),
                                    y: .value("Country", bucket.title)
                                )
                                .foregroundStyle(.blue.gradient)
                                .cornerRadius(8)
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .frame(height: 220)
                        }
                    }

                    if insights.topContentTypes.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Top Content Types")
                                .font(.subheadline.weight(.semibold))

                            Chart(insights.topContentTypes) { bucket in
                                BarMark(
                                    x: .value("Requests", bucket.requests),
                                    y: .value("Type", bucket.title)
                                )
                                .foregroundStyle(.teal.gradient)
                                .cornerRadius(8)
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .frame(height: 220)
                        }
                    }
                }
            } else {
                Text("Traffic profile analytics unavailable for this zone or token.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

private struct CacheSlice: Identifiable {
    let label: String
    let value: Double
    let tint: Color

    var id: String { label }
}
