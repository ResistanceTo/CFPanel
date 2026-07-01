import SwiftUI

struct SecurityView: View {
    @Environment(SecurityLevelViewModel.self) private var securityLevelViewModel
    @State private var path: [SecurityRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                postureSection
                incidentSection
            }
            .navigationTitle("Security")
            .navigationDestination(for: SecurityRoute.self) { route in
                switch route {
                case .overview:
                    SecurityOverviewView()
                case .rules:
                    RulesCenterView()
                case .incidentResponse:
                    PanicCenterView()
                }
            }
        }
    }

    private var postureSection: some View {
        Section {
            if let zoneName = securityLevelViewModel.selectedZone?.name {
                LabeledContent("Protected Site", value: zoneName)
            }

            Text("Use this section to review security posture and manage the standing policies that shape traffic handling.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink(value: SecurityRoute.overview) {
                CompactNavigationRow(
                    title: "Overview",
                    subtitle: "Load the active site's protection state and the quickest operational controls.",
                    systemImage: "shield"
                )
            }

            NavigationLink(value: SecurityRoute.rules) {
                CompactNavigationRow(
                    title: "Rules & Policies",
                    subtitle: "WAF, rate limiting, redirects, cache behavior, and other edge policies.",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
        } header: {
            Text("Posture & Policies")
        } footer: {
            Text("Site selection is managed in Sites. Connection and token details are managed in Settings.")
        }
    }

    private var incidentSection: some View {
        Section {
            Text("Use this section during active incidents when you need immediate mitigation or cache purge tools.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink(value: SecurityRoute.incidentResponse) {
                CompactNavigationRow(
                    title: "Incident Response",
                    subtitle: "Cache purge tools and emergency actions for the active site.",
                    systemImage: "bolt.shield"
                )
            }
        } header: {
            Text("Emergency Actions")
        }
    }
}

private enum SecurityRoute: Hashable {
    case overview
    case rules
    case incidentResponse
}

struct SecurityOverviewView: View {
    @Environment(SecurityLevelViewModel.self) private var securityLevelViewModel
    @State private var pendingUnderAttackMode: Bool?
    @State private var securityErrorMessage: String?

    var body: some View {
        Form {
            if let securityErrorMessage {
                Section("Status") {
                    Text(securityErrorMessage)
                        .foregroundStyle(.secondary)
                }
            }

            securityStatusSection
            securityLevelSection
        }
        .navigationTitle("Security Overview")
        .task(id: securityLevelViewModel.selectedZoneID) {
            guard let zoneID = securityLevelViewModel.selectedZoneID else { return }
            guard securityLevelViewModel.isSecurityLoaded(for: zoneID) == false else { return }
            do {
                try await securityLevelViewModel.refreshSecurityState()
                securityErrorMessage = nil
            } catch {
                securityErrorMessage = error.localizedDescription
            }
        }
        .refreshable {
            do {
                try await securityLevelViewModel.refreshSecurityState()
                securityErrorMessage = nil
            } catch {
                securityErrorMessage = error.localizedDescription
            }
        }
        .countdownConfirmationDialog(
            String(localized: underAttackConfirmationTitle),
            isPresented: isShowingUnderAttackConfirmation,
            message: underAttackConfirmationMessage,
            actionTitle: String(localized: underAttackConfirmationActionTitle),
            role: pendingUnderAttackMode == true ? .destructive : nil,
            onCancel: {
                pendingUnderAttackMode = nil
            }
        ) {
            guard let requestedUnderAttackMode = pendingUnderAttackMode else { return }
            Task {
                await securityLevelViewModel.setUnderAttackMode(requestedUnderAttackMode)
                pendingUnderAttackMode = nil
            }
        }
    }

    private var securityStatusSection: some View {
        Section("Overview") {
            Text(securityLevelViewModel.isUnderAttackModeEnabled ? "Under Attack Mode is active for the current site. Cloudflare will apply a more aggressive protection posture until you turn it off." : "The current site is running at its normal protection level.")
                .foregroundStyle(.secondary)

            if let zoneName = securityLevelViewModel.selectedZone?.name {
                LabeledContent("Applies To", value: zoneName)
            }

            Button {
                pendingUnderAttackMode = securityLevelViewModel.isUnderAttackModeEnabled == false
            } label: {
                Label(
                    securityLevelViewModel.isUnderAttackModeEnabled ? "Disable Under Attack Mode" : "Enable Under Attack Mode",
                    systemImage: securityLevelViewModel.isUnderAttackModeEnabled ? "shield.lefthalf.filled" : "shield"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(securityLevelViewModel.isUnderAttackModeEnabled ? .orange : .red)
            .disabled(securityLevelViewModel.isPerformingPanicAction || securityLevelViewModel.selectedZoneID == nil)

            Text("Use this for active incidents or obvious malicious traffic. This is reversible, but it affects live visitor experience immediately.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var securityLevelSection: some View {
        Section("Security Level") {
            Text(securityLevelViewModel.currentSecurityLevel.description)
                .foregroundStyle(.secondary)

            Picker("Security Level", selection: Binding.asyncValue(
                get: { securityLevelViewModel.isUnderAttackModeEnabled ? securityLevelViewModel.lastNonAttackSecurityLevel : securityLevelViewModel.currentSecurityLevel },
                set: { level in await securityLevelViewModel.updateSecurityLevel(level) }
            )) {
                ForEach(SecurityLevel.allCases.filter { $0 != .underAttack }) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .disabled(securityLevelViewModel.isUnderAttackModeEnabled || securityLevelViewModel.isRefreshingZoneControls || securityLevelViewModel.selectedZoneID == nil)
        }
    }

    private var isShowingUnderAttackConfirmation: Binding<Bool> {
        Binding(
            get: { pendingUnderAttackMode != nil },
            set: { isPresented in
                if isPresented == false {
                    pendingUnderAttackMode = nil
                }
            }
        )
    }

    private var underAttackConfirmationTitle: LocalizedStringResource {
        if pendingUnderAttackMode == true {
            return "Enable Under Attack Mode?"
        }
        return "Disable Under Attack Mode?"
    }

    private var underAttackConfirmationActionTitle: LocalizedStringResource {
        if pendingUnderAttackMode == true {
            return "Enable Now"
        }
        return "Disable Now"
    }

    private var underAttackConfirmationMessage: String {
        let zoneName = securityLevelViewModel.selectedZone?.name ?? "this zone"
        if pendingUnderAttackMode == true {
            return DangerousOperationMessage.liveChange(
                resource: "Security level",
                name: zoneName,
                from: String(localized: securityLevelViewModel.currentSecurityLevel.title),
                to: String(localized: SecurityLevel.underAttack.title),
                impact: "Cloudflare will immediately apply a more aggressive challenge flow. Real visitors may see additional checks."
            )
        }
        return DangerousOperationMessage.liveChange(
            resource: "Security level",
            name: zoneName,
            from: String(localized: SecurityLevel.underAttack.title),
            to: String(localized: securityLevelViewModel.lastNonAttackSecurityLevel.title),
            impact: "Cloudflare will return the site to its normal security posture immediately."
        )
    }
}
