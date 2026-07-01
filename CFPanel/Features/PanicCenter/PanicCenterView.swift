import SwiftUI

struct PanicCenterView: View {
    @Environment(SecurityLevelViewModel.self) private var securityLevelViewModel
    @Environment(CachePurgeViewModel.self) private var cachePurgeViewModel
    @State private var customPurgeURLs = ""
    @State private var isConfirmingPurgeEverything = false
    @State private var isConfirmingCustomPurge = false
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

            emergencyControlsSection
            cachePurgeSection
        }
        .navigationTitle("Incident Response")
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
            "Purge all cached assets for the active site?",
            isPresented: $isConfirmingPurgeEverything,
            message: purgeEverythingConfirmationMessage,
            actionTitle: "Purge Everything"
        ) {
            Task {
                await cachePurgeViewModel.purgeEverything()
            }
        }
        .countdownConfirmationDialog(
            "Purge listed URLs?",
            isPresented: $isConfirmingCustomPurge,
            message: customPurgeConfirmationMessage,
            actionTitle: "Purge Listed URLs",
            role: .destructive
        ) {
            let rawValue = customPurgeURLs
            Task {
                await cachePurgeViewModel.purgeCustomURLs(rawValue)
            }
        }
        .countdownConfirmationDialog(
            pendingUnderAttackMode == true ? "Enable Under Attack Mode?" : "Disable Under Attack Mode?",
            isPresented: Binding(
                get: { pendingUnderAttackMode != nil },
                set: { newValue in
                    if newValue == false {
                        pendingUnderAttackMode = nil
                    }
                }
            ),
            message: underAttackConfirmationMessage,
            actionTitle: pendingUnderAttackMode == true ? "Enable Under Attack Mode" : "Disable Under Attack Mode",
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

    private var emergencyControlsSection: some View {
        Section("Emergency Controls") {
            Text("Use these actions when you need a fast response on the road. They affect the active site immediately.")
                .foregroundStyle(.secondary)

            if let zoneName = securityLevelViewModel.selectedZone?.name {
                LabeledContent("Active Site", value: zoneName)
            }

            if securityLevelViewModel.selectedZone == nil {
                Label("Select an active site in Sites before using emergency actions.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
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

            Text("Under Attack Mode is reversible, but it changes how Cloudflare challenges incoming traffic right away.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var underAttackConfirmationMessage: String {
        let zoneName = securityLevelViewModel.selectedZone?.name ?? "the active site"
        if pendingUnderAttackMode == true {
            return DangerousOperationMessage.liveChange(
                resource: "Security level",
                name: zoneName,
                from: String(localized: securityLevelViewModel.currentSecurityLevel.title),
                to: String(localized: SecurityLevel.underAttack.title),
                impact: "Cloudflare will immediately apply stronger visitor challenges. Real users may see additional checks."
            )
        }
        return DangerousOperationMessage.liveChange(
            resource: "Security level",
            name: zoneName,
            from: String(localized: SecurityLevel.underAttack.title),
            to: String(localized: securityLevelViewModel.lastNonAttackSecurityLevel.title),
            impact: "Cloudflare will restore the previous security posture immediately."
        )
    }

    private var cachePurgeSection: some View {
        Section("Cache Purge") {
            Button("Purge Everything") {
                isConfirmingPurgeEverything = true
            }
            .buttonStyle(.bordered)
            .disabled(cachePurgeViewModel.isPerformingPanicAction || cachePurgeViewModel.selectedZoneID == nil)

            Text("Purge Everything clears the active site's cached assets globally and can increase origin load until the cache is warm again.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Add one URL per line. Use this when you only want to flush a subset of assets.")
                .foregroundStyle(.secondary)

            Text("Limit 30 URLs per request. URLs must belong to the active site.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextEditor(text: $customPurgeURLs)
                .frame(minHeight: 120)
                .padding(12)
                .background(.quinary, in: .rect(cornerRadius: 16))

            Button("Purge Listed URLs") {
                isConfirmingCustomPurge = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(cachePurgeViewModel.isPerformingPanicAction || cachePurgeViewModel.selectedZoneID == nil)
        }
    }

    private var customPurgeConfirmationMessage: String {
        let urls = customPurgeURLs
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let preview = urls.prefix(3).joined(separator: "\n")
        let suffix = urls.count > 3 ? "\n...and \(urls.count - 3) more" : ""
        let target = preview.isEmpty ? "No URLs entered" : "\(preview)\(suffix)"
        return DangerousOperationMessage.destructive(
            resource: "Cache entries",
            name: target,
            scope: cachePurgeViewModel.selectedZone?.name,
            impact: "Cloudflare will evict the listed cached URLs globally. Origin traffic for those URLs may increase until cache warms again.",
            irreversible: false
        )
    }

    private var purgeEverythingConfirmationMessage: String {
        DangerousOperationMessage.destructive(
            resource: "Cache",
            name: cachePurgeViewModel.selectedZone?.name ?? "active site",
            impact: "Cloudflare will evict all cached assets globally. Origin traffic may increase until cache warms again.",
            irreversible: false
        )
    }
}
