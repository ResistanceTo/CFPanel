import SwiftUI

struct ZoneOverviewCard: View {
    let details: CloudflareZoneDetails?
    let dnsSettings: ZoneDNSSettings?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zone Overview")
                .font(.headline)

            if let details {
                Group {
                    overviewRow("Status", value: String(localized: details.statusTitle))
                    overviewRow("Type", value: details.type.map { String(localized: $0.title) } ?? "Unknown")
                    overviewRow("Paused", value: details.paused == true ? "Yes" : "No")
                    overviewRow("Account", value: details.account?.name ?? "Unavailable")
                    overviewRow("Registrar", value: details.originalRegistrar ?? "Unavailable")
                }

                if details.nameServers.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assigned Nameservers")
                            .font(.subheadline.weight(.semibold))
                        ForEach(details.nameServers, id: \.self) { nameserver in
                            Text(nameserver)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .truncationMode(.middle)
                        }
                    }
                }
            }

            if let dnsSettings {
                Divider()
                Group {
                    overviewRow("Zone Mode", value: String(localized: dnsSettings.zoneMode.title))
                    overviewRow("Flatten All CNAMEs", value: dnsSettings.flattenAllCNAMES ? "Enabled" : "Disabled")
                    overviewRow("Multi-provider DNS", value: dnsSettings.multiProvider ? "Enabled" : "Disabled")
                    overviewRow("Nameserver TTL", value: dnsSettings.nsTTL.formatted())
                }
            }

            if details == nil, dnsSettings == nil {
                ContentUnavailableView("No Zone Metadata", systemImage: "globe")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private func overviewRow(_ title: LocalizedStringResource, value: String) -> some View {
        LabeledContent {
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        } label: {
            Text(title)
                .lineLimit(1)
        }
            .font(.subheadline)
    }
}
