import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AuthenticationViewModel.self) private var authenticationViewModel
    @Environment(SitesViewModel.self) private var sitesViewModel
    @State private var requestLogStore = HTTPRequestLogStore.shared
    @State private var isUpdatingCredentialStorageMode = false
    @State private var isUpdatingDangerousMode = false
    @State private var dangerousModeErrorMessage: String?
    @AppStorage("pinned_zone_id") private var pinnedZoneID: String = ""
    @AppStorage(DangerousOperationsSettings.advancedModeStorageKey) private var isAdvancedDangerousModeEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Startup") {
                    Picker("Default Site", selection: pinnedZoneSelectionBinding) {
                        Text("None").tag("")
                        ForEach(sitesViewModel.zones) { zone in
                            Text(zone.name).tag(zone.id)
                        }
                    }

                    Button("Clear Default Site") {
                        pinnedZoneID = ""
                    }
                    .disabled(pinnedZoneID.isEmpty)

                    SettingsFootnote("Settings only controls startup preference. Active site switching and site status live in Sites.")
                }

                SettingsConnectionSection(
                    authenticationMethod: authenticationViewModel.authenticationMethod,
                    credentialStorageMode: authenticationViewModel.credentialStorageMode,
                    accountID: authenticationViewModel.accountIDInput,
                    oauthAccountName: authenticationViewModel.oauthAccountName,
                    oauthGrantedScopes: authenticationViewModel.oauthGrantedScopes,
                    tokenVerification: authenticationViewModel.tokenVerification,
                    isUpdatingCredentialStorageMode: isUpdatingCredentialStorageMode,
                    credentialStorageModeBinding: credentialStorageModeBinding
                )

                SettingsDangerousModeSection(
                    isUpdatingDangerousMode: isUpdatingDangerousMode,
                    errorMessage: dangerousModeErrorMessage,
                    dangerousModeBinding: dangerousModeBinding
                )

//                Section("Diagnostics") {
//                    NavigationLink {
//                        HTTPRequestLogView()
//                    } label: {
//                        LabeledContent("HTTP Request Log", value: "\(requestLogStore.totalRequestCount)")
//                    }
//
//                    SettingsFootnote("The request log keeps redacted endpoints, status codes, duration, attempts, and errors locally.")
//                }

                Section("Project") {
                    NavigationLink {
                        SupportCFPanelView()
                    } label: {
                        SettingsMenuRow(
                            title: "About & Support CFPanel",
                            detail: "Why CFPanel stays free, how it is maintained, and optional ways to help keep it sustainable."
                        )
                    }

                    NavigationLink {
                        SettingsPolicyAndPermissionsView()
                    } label: {
                        SettingsMenuRow(
                            title: "Privacy & Permissions",
                            detail: "Credential storage, local diagnostics, and recommended token or OAuth scopes."
                        )
                    }

                    SettingsFootnote("If CFPanel is useful in your daily Cloudflare work, optional support helps fund maintenance, testing, App Store costs, and ongoing API compatibility work without putting the app behind a paywall.")
                }

                Section("Session") {
                    Button("Sign Out", role: .destructive) {
                        authenticationViewModel.signOut()
                    }

                    SettingsFootnote("Signing out removes the saved Cloudflare credential from this device and clears the local workspace session.")
                }
            }
            .navigationTitle("Settings")
            .refreshable {
                await sitesViewModel.refreshWorkspace(preferredZoneID: sitesViewModel.selectedZoneID ?? pinnedZoneID)
            }
        }
    }

    private var credentialStorageModeBinding: Binding<CredentialStorageMode> {
        Binding(
            get: { authenticationViewModel.credentialStorageMode },
            set: { newMode in
                guard isUpdatingCredentialStorageMode == false else { return }
                isUpdatingCredentialStorageMode = true
                Task {
                    await authenticationViewModel.updateCredentialStorageMode(newMode)
                    isUpdatingCredentialStorageMode = false
                }
            }
        )
    }

    private var pinnedZoneSelectionBinding: Binding<String> {
        Binding(
            get: {
                guard pinnedZoneID.isEmpty == false else { return "" }
                return sitesViewModel.zones.contains(where: { $0.id == pinnedZoneID }) ? pinnedZoneID : ""
            },
            set: { newValue in
                pinnedZoneID = newValue
            }
        )
    }

    private var isPinnedZoneUnavailable: Bool {
        guard pinnedZoneID.isEmpty == false else { return false }
        guard sitesViewModel.zones.isEmpty == false else { return false }
        return sitesViewModel.zones.contains(where: { $0.id == pinnedZoneID }) == false
    }

    private var dangerousModeBinding: Binding<Bool> {
        Binding(
            get: { isAdvancedDangerousModeEnabled },
            set: { newValue in
                guard isUpdatingDangerousMode == false else { return }

                if newValue == false {
                    dangerousModeErrorMessage = nil
                    isAdvancedDangerousModeEnabled = false
                    return
                }

                isUpdatingDangerousMode = true
                Task {
                    do {
                        try await DangerousActionAuthorizer.authorize(
                            reason: "Confirm enabling Advanced Dangerous Mode in CFPanel."
                        )
                        isAdvancedDangerousModeEnabled = true
                        dangerousModeErrorMessage = nil
                    } catch {
                        isAdvancedDangerousModeEnabled = false
                        dangerousModeErrorMessage = error.localizedDescription
                    }
                    isUpdatingDangerousMode = false
                }
            }
        )
    }
}

struct SettingsFootnote: View {
    let text: LocalizedStringResource

    init(_ text: LocalizedStringResource) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

private struct SettingsMenuRow: View {
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct SettingsPolicyAndPermissionsView: View {
    var body: some View {
        Form {
            Section("Privacy") {
//                SettingsFootnote("Credentials are stored in Keychain on this device. Local preferences stay on-device unless you add a sync capability in a future release.")
                SettingsFootnote("Operational data is requested from Cloudflare as needed. Request diagnostics redact resource identifiers before local storage.")
            }

            Section("Token Permissions") {
                TokenPermissionGuidanceRows()
                SettingsFootnote("For Account Token mode, confirm that the configured account token matches the 32-character account ID in CFPanel. For OAuth mode, sign out and authorize again if required scopes are missing.")
            }
        }
        .navigationTitle("Privacy & Permissions")
    }
}

private struct AboutPrincipleRow: View {
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct HTTPRequestLogView: View {
    @State private var requestLogStore = HTTPRequestLogStore.shared
    @State private var exportDocument = TextExportDocument(text: "")
    @State private var exportFileName = "cfpanel-http-failures.json"
    @State private var showExporter = false

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Requests", value: requestLogStore.totalRequestCount.formatted())
                LabeledContent("Failures", value: requestLogStore.failureCount.formatted())
                Text("Asset identifiers, KV keys, script names, project names, and query values are hidden in this view.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    exportDocument = TextExportDocument(text: requestLogStore.exportJSON())
                    exportFileName = "cfpanel-http-failures-\(Self.exportTimestamp).json"
                    showExporter = true
                } label: {
                    Label("Export Failures", systemImage: "square.and.arrow.up")
                }
                .disabled(requestLogStore.failureCount == 0)

                Button("Clear Log", role: .destructive) {
                    requestLogStore.clear()
                }
                .disabled(requestLogStore.entries.isEmpty)
            }

            if requestLogStore.endpointSummaries.isEmpty == false {
                Section("Endpoints") {
                    ForEach(requestLogStore.endpointSummaries) { summary in
                        LabeledContent(summary.endpoint, value: summary.count.formatted())
                            .font(.footnote)
                    }
                }
            }

            Section("Recent Requests") {
                if requestLogStore.entries.isEmpty {
                    ContentUnavailableView(
                        "No Requests Logged",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Open a page that loads Cloudflare data to collect request counts.")
                    )
                } else {
                    ForEach(requestLogStore.entries) { entry in
                        HTTPRequestLogRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("HTTP Requests")
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName
        ) { _ in }
    }

    private static var exportTimestamp: String {
        Date().formatted(
            .iso8601
                .year()
                .month()
                .day()
                .time(includingFractionalSeconds: false)
                .timeSeparator(.omitted)
        )
    }
}

private struct HTTPRequestLogRow: View {
    let entry: HTTPRequestLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(entry.method) \(entry.statusText)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(entry.isFailure ? .red : .primary)

                Spacer()

                Text("\(entry.durationMilliseconds) ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.pathAndQuery)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                Text("Attempt \(entry.attempt)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let errorMessage = entry.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ZoneSettingsView: View {
    @Environment(ZoneSettingsDirectoryViewModel.self) private var zoneSettingsDirectoryViewModel

    var body: some View {
        Form {
            Section("Current Site") {
                if let zone = zoneSettingsDirectoryViewModel.selectedZone {
                    LabeledContent("Active Site", value: zone.name)
                    LabeledContent("Status", value: String(localized: zone.statusTitle))
                } else {
                    Text("Select an active site before opening deeper settings pages.")
                        .foregroundStyle(.secondary)
                }

                Text("This page is a directory only. Detailed zone settings now load in deeper pages so this layer stays light.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Available Menus") {
                NavigationLink {
                    ZoneTrafficControlsSettingsView()
                } label: {
                    SettingsMenuRow(
                        title: "Traffic Controls",
                        detail: "Always Use HTTPS, HTTPS rewrites, Development Mode, and Always Online."
                    )
                }
                .disabled(zoneSettingsDirectoryViewModel.selectedZoneID == nil)

                NavigationLink {
                    ZoneSecurityControlsSettingsView()
                } label: {
                    SettingsMenuRow(
                        title: "Security Controls",
                        detail: "Browser Integrity Check, WAF, and Bot Fight Mode."
                    )
                }
                .disabled(zoneSettingsDirectoryViewModel.selectedZoneID == nil)

                NavigationLink {
                    ZoneEdgeFeaturesView()
                } label: {
                    SettingsMenuRow(
                        title: "Edge Features",
                        detail: "HTTP/3, TLS 1.3, WebSockets, 0-RTT, IP geolocation, and WebP."
                    )
                }
                .disabled(zoneSettingsDirectoryViewModel.selectedZoneID == nil)
            }
        }
        .navigationTitle("Advanced Settings")
    }
}

struct ZoneTrafficControlsSettingsView: View {
    @Environment(ZoneTrafficControlsViewModel.self) private var zoneTrafficControlsViewModel

    var body: some View {
        Form {
            Section("Traffic Controls") {
                zoneControlToggle(.alwaysUseHTTPS)
                zoneControlToggle(.automaticHTTPSRewrites)
                zoneControlToggle(.developmentMode)
                zoneControlToggle(.alwaysOnline)
            }
            .disabled(zoneTrafficControlsViewModel.selectedZoneID == nil || zoneTrafficControlsViewModel.isRefreshingZoneControls)
        }
        .navigationTitle("Traffic Controls")
        .task(id: zoneTrafficControlsViewModel.selectedZoneID) {
            guard let zoneID = zoneTrafficControlsViewModel.selectedZoneID else { return }
            guard zoneTrafficControlsViewModel.isLoaded(for: zoneID) == false else { return }
            do {
                try await zoneTrafficControlsViewModel.refreshTrafficZoneControls()
            } catch {
                zoneTrafficControlsViewModel.presentError(error)
            }
        }
        .refreshable {
            do {
                try await zoneTrafficControlsViewModel.refreshTrafficZoneControls(force: true)
            } catch {
                zoneTrafficControlsViewModel.presentError(error)
            }
        }
    }

    private func zoneControlToggle(_ toggle: ZoneControlToggle) -> some View {
        ZoneControlRow(
            title: toggle.title,
            detail: toggle.description,
            isOn: Binding.asyncValue(
                get: { value(for: toggle) },
                set: { newValue in
                    await zoneTrafficControlsViewModel.updateZoneControl(toggle, enabled: newValue)
                }
            )
        )
    }

    private func value(for toggle: ZoneControlToggle) -> Bool {
        switch toggle {
        case .alwaysUseHTTPS:
            zoneTrafficControlsViewModel.zoneControls.alwaysUseHTTPS
        case .automaticHTTPSRewrites:
            zoneTrafficControlsViewModel.zoneControls.automaticHTTPSRewrites
        case .developmentMode:
            zoneTrafficControlsViewModel.zoneControls.developmentMode
        case .alwaysOnline:
            zoneTrafficControlsViewModel.zoneControls.alwaysOnline
        case .browserIntegrityCheck, .waf, .botFightMode:
            false
        }
    }
}

struct ZoneSecurityControlsSettingsView: View {
    @Environment(ZoneSecurityControlsViewModel.self) private var zoneSecurityControlsViewModel

    var body: some View {
        Form {
            Section("Security Controls") {
                zoneControlToggle(.browserIntegrityCheck)
                zoneControlToggle(.waf)
                zoneControlToggle(.botFightMode)
            }
            .disabled(zoneSecurityControlsViewModel.selectedZoneID == nil || zoneSecurityControlsViewModel.isRefreshingZoneControls)
        }
        .navigationTitle("Security Controls")
        .task(id: zoneSecurityControlsViewModel.selectedZoneID) {
            guard let zoneID = zoneSecurityControlsViewModel.selectedZoneID else { return }
            guard zoneSecurityControlsViewModel.isLoaded(for: zoneID) == false else { return }
            do {
                try await zoneSecurityControlsViewModel.refreshSecurityZoneControls()
            } catch {
                zoneSecurityControlsViewModel.presentError(error)
            }
        }
        .refreshable {
            do {
                try await zoneSecurityControlsViewModel.refreshSecurityZoneControls(force: true)
            } catch {
                zoneSecurityControlsViewModel.presentError(error)
            }
        }
    }

    private func zoneControlToggle(_ toggle: ZoneControlToggle) -> some View {
        ZoneControlRow(
            title: toggle.title,
            detail: toggle.description,
            unavailableMessage: zoneSecurityControlsViewModel.unavailableZoneControls[toggle],
            isOn: Binding.asyncValue(
                get: { value(for: toggle) },
                set: { newValue in
                    await zoneSecurityControlsViewModel.updateZoneControl(toggle, enabled: newValue)
                }
            )
        )
    }

    private func value(for toggle: ZoneControlToggle) -> Bool {
        switch toggle {
        case .browserIntegrityCheck:
            zoneSecurityControlsViewModel.zoneControls.browserIntegrityCheck
        case .waf:
            zoneSecurityControlsViewModel.zoneControls.waf
        case .botFightMode:
            zoneSecurityControlsViewModel.zoneControls.botFightMode
        case .alwaysUseHTTPS, .automaticHTTPSRewrites, .developmentMode, .alwaysOnline:
            false
        }
    }
}

struct ZoneEdgeFeaturesView: View {
    @Environment(ZoneEdgeFeaturesViewModel.self) private var zoneEdgeFeaturesViewModel

    var body: some View {
        Form {
            Section("Edge Features") {
                advancedToggleRow(
                    title: ZoneAdvancedToggle.http3.title,
                    detail: ZoneAdvancedToggle.http3.description,
                    unavailableMessage: zoneEdgeFeaturesViewModel.unavailableZoneAdvancedSettings[.http3],
                    value: Binding.asyncValue(
                        get: { zoneEdgeFeaturesViewModel.zoneAdvancedSettings.http3 },
                        set: { newValue in
                            await zoneEdgeFeaturesViewModel.updateAdvancedZoneSetting(.http3, enabled: newValue)
                        }
                    )
                )

                advancedToggleRow(
                    title: ZoneAdvancedToggle.tls13.title,
                    detail: ZoneAdvancedToggle.tls13.description,
                    unavailableMessage: zoneEdgeFeaturesViewModel.unavailableZoneAdvancedSettings[.tls13],
                    value: Binding.asyncValue(
                        get: { zoneEdgeFeaturesViewModel.zoneAdvancedSettings.tls13 },
                        set: { newValue in
                            await zoneEdgeFeaturesViewModel.updateAdvancedZoneSetting(.tls13, enabled: newValue)
                        }
                    )
                )

                advancedToggleRow(
                    title: ZoneAdvancedToggle.webSockets.title,
                    detail: ZoneAdvancedToggle.webSockets.description,
                    unavailableMessage: zoneEdgeFeaturesViewModel.unavailableZoneAdvancedSettings[.webSockets],
                    value: Binding.asyncValue(
                        get: { zoneEdgeFeaturesViewModel.zoneAdvancedSettings.webSockets },
                        set: { newValue in
                            await zoneEdgeFeaturesViewModel.updateAdvancedZoneSetting(.webSockets, enabled: newValue)
                        }
                    )
                )

                advancedToggleRow(
                    title: ZoneAdvancedToggle.zeroRTT.title,
                    detail: ZoneAdvancedToggle.zeroRTT.description,
                    unavailableMessage: zoneEdgeFeaturesViewModel.unavailableZoneAdvancedSettings[.zeroRTT],
                    value: Binding.asyncValue(
                        get: { zoneEdgeFeaturesViewModel.zoneAdvancedSettings.zeroRTT },
                        set: { newValue in
                            await zoneEdgeFeaturesViewModel.updateAdvancedZoneSetting(.zeroRTT, enabled: newValue)
                        }
                    )
                )

                advancedToggleRow(
                    title: ZoneAdvancedToggle.ipGeolocation.title,
                    detail: ZoneAdvancedToggle.ipGeolocation.description,
                    unavailableMessage: zoneEdgeFeaturesViewModel.unavailableZoneAdvancedSettings[.ipGeolocation],
                    value: Binding.asyncValue(
                        get: { zoneEdgeFeaturesViewModel.zoneAdvancedSettings.ipGeolocation },
                        set: { newValue in
                            await zoneEdgeFeaturesViewModel.updateAdvancedZoneSetting(.ipGeolocation, enabled: newValue)
                        }
                    )
                )

                advancedToggleRow(
                    title: ZoneAdvancedToggle.webP.title,
                    detail: ZoneAdvancedToggle.webP.description,
                    unavailableMessage: zoneEdgeFeaturesViewModel.unavailableZoneAdvancedSettings[.webP],
                    value: Binding.asyncValue(
                        get: { zoneEdgeFeaturesViewModel.zoneAdvancedSettings.webP },
                        set: { newValue in
                            await zoneEdgeFeaturesViewModel.updateAdvancedZoneSetting(.webP, enabled: newValue)
                        }
                    )
                )
            }
            .disabled(zoneEdgeFeaturesViewModel.selectedZoneID == nil || zoneEdgeFeaturesViewModel.isRefreshingZoneControls)
        }
        .navigationTitle("Edge Features")
        .task(id: zoneEdgeFeaturesViewModel.selectedZoneID) {
            guard let zoneID = zoneEdgeFeaturesViewModel.selectedZoneID else { return }
            guard zoneEdgeFeaturesViewModel.isLoaded(for: zoneID) == false else { return }
            do {
                try await zoneEdgeFeaturesViewModel.refreshZoneAdvancedSettings()
            } catch {
                zoneEdgeFeaturesViewModel.presentError(error)
            }
        }
        .refreshable {
            do {
                try await zoneEdgeFeaturesViewModel.refreshZoneAdvancedSettings(force: true)
            } catch {
                zoneEdgeFeaturesViewModel.presentError(error)
            }
        }
    }

    private func advancedToggleRow(
        title: String,
        detail: LocalizedStringResource,
        unavailableMessage: String? = nil,
        value: Binding<Bool>
    ) -> some View {
        ZoneControlRow(title: title, detail: detail, unavailableMessage: unavailableMessage, isOn: value)
    }

}

struct ZoneControlRow: View {
    let title: String
    let detail: LocalizedStringResource
    let unavailableMessage: String?
    @Binding var isOn: Bool

    init(
        title: String,
        detail: LocalizedStringResource,
        unavailableMessage: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.detail = detail
        self.unavailableMessage = unavailableMessage
        _isOn = isOn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: $isOn)
                .disabled(unavailableMessage != nil)

            if let unavailableMessage, unavailableMessage.isEmpty == false {
                Label(unavailableMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
