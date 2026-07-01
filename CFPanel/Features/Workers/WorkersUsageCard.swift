import SwiftUI

struct WorkersUsageCard: View {
    let usage: WorkersUsageSnapshot?
    let runtimeCount: Int
    let message: String?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage Overview")
                        .font(.headline)
                }

                Spacer(minLength: 0)

                Text("\(runtimeCount) scripts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isRefreshing && usage == nil {
                ProgressView("Loading Usage")
            } else if let usage {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        usageMetric(
                            title: "Requests Today",
                            value: usage.requestsToday.compactAbbreviated,
                            detail: "\(usage.requestRemainingEstimate.compactAbbreviated) left",
                            tint: .blue
                        )
                        usageMetric(
                            title: "Requests Month",
                            value: usage.requestsMonth.compactAbbreviated,
                            detail: "\(usage.errorsMonth.compactAbbreviated) errors",
                            tint: .orange
                        )
                    }

                    HStack(spacing: 12) {
                        usageMetric(
                            title: "CPU Today",
                            value: usage.cpuTimeTodayMilliseconds.map(millisecondsText) ?? "n/a",
                            detail: usage.cpuP50Us.map(cpuQuantileText(prefix: "p50")) ?? "No latency sample",
                            tint: .green
                        )
                        usageMetric(
                            title: "Subrequests",
                            value: usage.subrequestsMonth.compactAbbreviated,
                            detail: usage.errorRatePercent.map(errorRateText) ?? "No request sample",
                            tint: .teal
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Free-tier request budget")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text("\(usage.requestsToday.compactAbbreviated) / \(usage.requestQuotaEstimate.compactAbbreviated)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: usage.requestUsageRatio)
                        .tint(usage.requestUsageRatio > 0.85 ? .orange : .blue)
                }

                if let message, message.isEmpty == false {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(message ?? "Workers usage is unavailable for the current token or account context.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private func usageMetric(
        title: LocalizedStringResource,
        value: String,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quinary, in: .rect(cornerRadius: 16))
    }

    private func millisecondsText(_ milliseconds: Double) -> String {
        if milliseconds >= 1_000 {
            return "\(Int(milliseconds.rounded())).ms"
        }
        return milliseconds.formatted(.number.precision(.fractionLength(0 ... 1))) + "ms"
    }

    private func cpuQuantileText(prefix: String) -> (Double) -> String {
        { value in
            let milliseconds = value / 1_000
            return "\(prefix) \(milliseconds.formatted(.number.precision(.fractionLength(0 ... 1))))ms"
        }
    }

    private func errorRateText(_ rate: Double) -> String {
        "Error rate \(rate.formatted(.number.precision(.fractionLength(1))))%"
    }
}
