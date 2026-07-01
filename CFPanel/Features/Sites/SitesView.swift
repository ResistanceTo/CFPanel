import SwiftUI

struct SitesView: View {
    @Environment(SitesViewModel.self) private var sitesViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("pinned_zone_id") private var pinnedZoneID: String = ""
    @State private var path: [SitesRoute] = []
    @State private var selectedRoute: SitesRoute? = .overview

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
            List {
                currentZoneSection
                statusAndInventorySection
                routingAndDeliverySection
                mailFlowsSection
                siteControlsSection
                zonesSection
            }
            .navigationTitle("Sites")
            .refreshable {
                await refreshWorkspace()
            }
            .navigationDestination(for: SitesRoute.self) { route in
                destinationView(for: route)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: $selectedRoute) {
                currentZoneSection
                workspaceSection
                zonesSection
            }
            .navigationTitle("Sites")
            .navigationSplitViewColumnWidth(min: 320, ideal: 360)
            .refreshable {
                await refreshWorkspace()
            }
        } detail: {
            NavigationStack {
                if let selectedRoute {
                    destinationView(for: selectedRoute)
                } else {
                    ContentUnavailableView(
                        "Select a Site Tool",
                        systemImage: "square.grid.2x2",
                        description: Text("Choose a workspace tool from the sidebar to manage the active site.")
                    )
                }
            }
        }
    }

    private var workspaceSection: some View {
        Section("Workspace") {
            ForEach(SitesRoute.allCases) { route in
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
    private func destinationView(for route: SitesRoute) -> some View {
        switch route {
        case .overview:
            SiteOverviewView()
        case .dnsRecords:
            DNSRecordsView()
        case .dnsSettings:
            SiteDNSSettingsView()
        case .sslTLS:
            SiteSSLTLSView()
        case .caching:
            SiteCachingView()
        case .emailRouting:
            EmailRoutingWorkspaceView()
        case .emailSending:
            EmailSendingWorkspaceView()
        case .advancedSettings:
            ZoneSettingsView()
        }
    }

    private func refreshWorkspace() async {
        await sitesViewModel.refreshWorkspace(preferredZoneID: sitesViewModel.selectedZoneID ?? pinnedZoneID)
    }

    private var currentZoneSection: some View {
        Section {
            Picker("Switch Site", selection: activeZoneSelection) {
                ForEach(sitesViewModel.zones) { zone in
                    Text(zone.name).tag(zone.id)
                }
            }
            .disabled(sitesViewModel.zones.isEmpty)
            
            if let zone = sitesViewModel.selectedZone {
//                LabeledContent("Active Site", value: zone.name)
                LabeledContent("Site Status", value: String(localized: zone.statusTitle))
            } else {
                Text("Select a site below before opening zone-scoped tools.")
                    .foregroundStyle(.secondary)
            }

            if let lastRefreshAt = sitesViewModel.lastRefreshAt {
                LabeledContent("Sites Refreshed", value: lastRefreshAt.formatted(date: .abbreviated, time: .shortened))
            }
        } header: {
            Text("Current Site")
        } footer: {
            Text("Sites owns active site selection. Token status and storage are managed in Settings.")
        }
    }

    private var statusAndInventorySection: some View {
        Section("Status & Inventory") {
            NavigationLink(value: SitesRoute.overview) {
                CompactNavigationRow(
                    title: SitesRoute.overview.title,
                    subtitle: SitesRoute.overview.subtitle,
                    systemImage: SitesRoute.overview.systemImage
                )
            }

            NavigationLink(value: SitesRoute.dnsRecords) {
                CompactNavigationRow(
                    title: SitesRoute.dnsRecords.title,
                    subtitle: SitesRoute.dnsRecords.subtitle,
                    systemImage: SitesRoute.dnsRecords.systemImage
                )
            }
        }
    }

    private var routingAndDeliverySection: some View {
        Section("Routing & Delivery") {
            NavigationLink(value: SitesRoute.dnsSettings) {
                CompactNavigationRow(
                    title: SitesRoute.dnsSettings.title,
                    subtitle: SitesRoute.dnsSettings.subtitle,
                    systemImage: SitesRoute.dnsSettings.systemImage
                )
            }

            NavigationLink(value: SitesRoute.sslTLS) {
                CompactNavigationRow(
                    title: SitesRoute.sslTLS.title,
                    subtitle: SitesRoute.sslTLS.subtitle,
                    systemImage: SitesRoute.sslTLS.systemImage
                )
            }

            NavigationLink(value: SitesRoute.caching) {
                CompactNavigationRow(
                    title: SitesRoute.caching.title,
                    subtitle: SitesRoute.caching.subtitle,
                    systemImage: SitesRoute.caching.systemImage
                )
            }
        }
    }

    private var siteControlsSection: some View {
        Section("Site Controls") {
            NavigationLink(value: SitesRoute.advancedSettings) {
                CompactNavigationRow(
                    title: SitesRoute.advancedSettings.title,
                    subtitle: SitesRoute.advancedSettings.subtitle,
                    systemImage: SitesRoute.advancedSettings.systemImage
                )
            }
        }
    }

    private var mailFlowsSection: some View {
        Section("Mail Flows") {
            NavigationLink(value: SitesRoute.emailRouting) {
                CompactNavigationRow(
                    title: SitesRoute.emailRouting.title,
                    subtitle: SitesRoute.emailRouting.subtitle,
                    systemImage: SitesRoute.emailRouting.systemImage
                )
            }

            NavigationLink(value: SitesRoute.emailSending) {
                CompactNavigationRow(
                    title: SitesRoute.emailSending.title,
                    subtitle: SitesRoute.emailSending.subtitle,
                    systemImage: SitesRoute.emailSending.systemImage
                )
            }
        }
    }

    private var zonesSection: some View {
        Section {
            Text("Tap to switch the active site. Default site is managed in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if sitesViewModel.zones.isEmpty {
                ContentUnavailableView("No Zone Found", systemImage: "globe")
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(sitesViewModel.zones) { zone in
                    Button {
                        sitesViewModel.switchSelectedZone(zone.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: zone.id == sitesViewModel.selectedZoneID ? "checkmark.circle.fill" : "globe")
                                .foregroundStyle(zone.id == sitesViewModel.selectedZoneID ? .blue : .secondary)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(zone.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(String(localized: zone.statusTitle))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            VStack(alignment: .trailing, spacing: 6) {
                                if zone.id == sitesViewModel.selectedZoneID {
                                    statusBadge(title: "Current", systemImage: "checkmark.circle.fill", tint: .blue)
                                }

                                if zone.id == pinnedZoneID, pinnedZoneID.isEmpty == false {
                                    statusBadge(title: "Default", systemImage: "pin.fill", tint: .secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("All Sites")
        }
    }

    private func statusBadge(title: LocalizedStringResource, systemImage: String, tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }

    private var activeZoneSelection: Binding<String> {
        Binding(
            get: { sitesViewModel.selectedZoneID ?? "" },
            set: { zoneID in
                guard zoneID.isEmpty == false else { return }
                sitesViewModel.switchSelectedZone(zoneID)
            }
        )
    }
}

private enum SitesRoute: Hashable {
    case overview
    case dnsRecords
    case dnsSettings
    case sslTLS
    case caching
    case emailRouting
    case emailSending
    case advancedSettings
}

extension SitesRoute: CaseIterable, Identifiable {
    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .overview: "Overview"
        case .dnsRecords: "DNS Records"
        case .dnsSettings: "DNS Settings"
        case .sslTLS: "SSL/TLS"
        case .caching: "Caching"
        case .emailRouting: "Email Routing"
        case .emailSending: "Email Sending"
        case .advancedSettings: "Advanced Settings"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .overview:
            "Status, account, registrar, and nameserver metadata for the active site."
        case .dnsRecords:
            "Records, imports, and scan review for the active site."
        case .dnsSettings:
            "Zone mode, CNAME flattening, Foundation DNS, and nameserver TTL."
        case .sslTLS:
            "Encryption mode, minimum TLS version, and HTTPS-related controls."
        case .caching:
            "Development Mode and Always Online are grouped here as delivery controls."
        case .emailRouting:
            "Enable receiving, review DNS readiness, manage destination addresses, and inspect routing rules."
        case .emailSending:
            "Inspect sending subdomains and the DNS records required for outbound mail."
        case .advancedSettings:
            "Zone controls and edge features that are not already exposed in the primary site menus."
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "info.circle"
        case .dnsRecords: "network"
        case .dnsSettings: "server.rack"
        case .sslTLS: "lock.shield"
        case .caching: "externaldrive.badge.checkmark"
        case .emailRouting: "envelope.badge"
        case .emailSending: "paperplane"
        case .advancedSettings: "slider.horizontal.3"
        }
    }
}
