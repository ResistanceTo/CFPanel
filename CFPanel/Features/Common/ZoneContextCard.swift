import SwiftUI

struct ZoneContextCard: View {
    let zone: CloudflareZone?
    let tokenVerification: TokenVerification?
    let lastRefreshAt: Date?
    let recordCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Context")
                        .font(.headline)

                    Text(zone?.name ?? "No zone selected")
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    if let zone {
                        Label {
                            Text(zone.statusTitle)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "dot.radiowaves.left.and.right")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 16)

                if let tokenVerification {
                    TokenStatusBadge(status: tokenVerification.status)
                }
            }

            if let tokenVerification {
                contextRow(title: "Token ID", value: tokenVerification.id.middleEllipsizedToken, monospaced: true)
            }

            if let recordCount {
                contextRow(title: "DNS Records", value: recordCount.formatted())
            }

            if let lastRefreshAt {
                contextRow(
                    title: "Last Refresh",
                    value: lastRefreshAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private func contextRow(title: LocalizedStringResource, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .font(monospaced ? .system(.subheadline, design: .monospaced) : .subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.middle)
        }
    }
}

private struct TokenStatusBadge: View {
    let status: TokenVerification.Status

    var body: some View {
        Label {
            Text(status.title)
        } icon: {
            Image(systemName: statusIcon)
        }
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.tint.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .combine)
    }

    private var statusIcon: String {
        switch status {
        case .active:
            "checkmark.seal.fill"
        case .disabled:
            "pause.circle.fill"
        case .expired:
            "clock.badge.exclamationmark.fill"
        }
    }
}
