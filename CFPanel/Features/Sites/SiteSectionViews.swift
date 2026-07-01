import SwiftUI

struct SiteOverviewView: View {
    @Environment(SiteOverviewViewModel.self) private var siteOverviewViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZoneOverviewCard(
                    details: siteOverviewViewModel.zoneDetails,
                    dnsSettings: nil
                )
                zonePauseCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Overview")
        .task(id: siteOverviewViewModel.selectedZoneID) {
            guard let zoneID = siteOverviewViewModel.selectedZoneID else { return }
            guard siteOverviewViewModel.isLoaded(for: zoneID) == false else { return }
            do {
                try await siteOverviewViewModel.refreshZoneOverview()
            } catch {
                siteOverviewViewModel.presentError(error)
            }
        }
        .refreshable {
            do {
                try await siteOverviewViewModel.refreshZoneOverview(force: true)
            } catch {
                siteOverviewViewModel.presentError(error)
            }
        }
    }

    private var zonePauseCard: some View {
        let isPaused = siteOverviewViewModel.zoneDetails?.paused == true
        return VStack(alignment: .leading, spacing: 12) {
            Text("Zone Status")
                .font(.headline)
            Text(isPaused
                ? "This zone is paused. All traffic is bypassing Cloudflare and going directly to your origin."
                : "This zone is active. Cloudflare is processing traffic according to your configuration."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button {
                Task { await siteOverviewViewModel.toggleZonePause(!isPaused) }
            } label: {
                Label(
                    isPaused ? "Resume Zone" : "Pause Zone",
                    systemImage: isPaused ? "play.circle" : "pause.circle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isPaused ? .green : .orange)
            .disabled(siteOverviewViewModel.selectedZoneID == nil || siteOverviewViewModel.isRefreshingZoneControls)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct SiteDNSSettingsView: View {
    @Environment(SiteDNSSettingsViewModel.self) private var siteDNSSettingsViewModel

    var body: some View {
        Form {
            Section("DNS Configuration") {
                if let zoneDNSSettings = siteDNSSettingsViewModel.zoneDNSSettings {
                    LabeledContent("Zone Mode", value: String(localized: zoneDNSSettings.zoneMode.title))
                    LabeledContent("Flatten All CNAMEs", value: zoneDNSSettings.flattenAllCNAMES ? "Enabled" : "Disabled")
                    LabeledContent("Multi-provider DNS", value: zoneDNSSettings.multiProvider ? "Enabled" : "Disabled")
                    LabeledContent("Foundation DNS", value: zoneDNSSettings.foundationDNS ? "Enabled" : "Disabled")
                    LabeledContent("Nameserver TTL", value: zoneDNSSettings.nsTTL.formatted())
                } else {
                    Text("No DNS settings loaded for the selected zone.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("DNS Settings")
        .task(id: siteDNSSettingsViewModel.selectedZoneID) {
            guard let zoneID = siteDNSSettingsViewModel.selectedZoneID else { return }
            guard siteDNSSettingsViewModel.isLoaded(for: zoneID) == false else { return }
            do {
                try await siteDNSSettingsViewModel.refreshDNSSettings()
            } catch {
                siteDNSSettingsViewModel.presentError(error)
            }
        }
        .refreshable {
            do {
                try await siteDNSSettingsViewModel.refreshDNSSettings(force: true)
            } catch {
                siteDNSSettingsViewModel.presentError(error)
            }
        }
    }
}

struct SiteSSLTLSView: View {
    @Environment(SiteTLSViewModel.self) private var siteTLSViewModel

    var body: some View {
        Form {
            Section("Encryption") {
                Picker(
                    "Encryption Mode",
                    selection: Binding.asyncValue(
                        get: { siteTLSViewModel.edgeTLSSettings.sslMode },
                        set: { newValue in
                            await siteTLSViewModel.updateSSLMode(newValue)
                        }
                    )
                ) {
                    ForEach(CloudflareSSLMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker(
                    "Minimum TLS Version",
                    selection: Binding.asyncValue(
                        get: { siteTLSViewModel.edgeTLSSettings.minimumTLSVersion },
                        set: { newValue in
                            await siteTLSViewModel.updateMinimumTLSVersion(newValue)
                        }
                    )
                ) {
                    ForEach(MinimumTLSVersion.allCases) { version in
                        Text(version.title).tag(version)
                    }
                }
            }

            Section("HTTPS") {
                ZoneControlRow(
                    title: ZoneControlToggle.alwaysUseHTTPS.title,
                    detail: ZoneControlToggle.alwaysUseHTTPS.description,
                    isOn: Binding.asyncValue(
                        get: { siteTLSViewModel.zoneControls.alwaysUseHTTPS },
                        set: { newValue in
                            await siteTLSViewModel.updateZoneControl(.alwaysUseHTTPS, enabled: newValue)
                        }
                    )
                )

                ZoneControlRow(
                    title: ZoneControlToggle.automaticHTTPSRewrites.title,
                    detail: ZoneControlToggle.automaticHTTPSRewrites.description,
                    isOn: Binding.asyncValue(
                        get: { siteTLSViewModel.zoneControls.automaticHTTPSRewrites },
                        set: { newValue in
                            await siteTLSViewModel.updateZoneControl(.automaticHTTPSRewrites, enabled: newValue)
                        }
                    )
                )
            }

            Section {
                ZoneControlRow(
                    title: "HSTS",
                    detail: "Enable HTTP Strict Transport Security to instruct browsers to only connect via HTTPS.",
                    isOn: Binding.asyncValue(
                        get: { siteTLSViewModel.edgeTLSSettings.hsts.enabled },
                        set: { enabled in
                            var updated = siteTLSViewModel.edgeTLSSettings.hsts
                            updated.enabled = enabled
                            await siteTLSViewModel.updateHSTSSettings(updated)
                        }
                    )
                )

                if siteTLSViewModel.edgeTLSSettings.hsts.enabled {
                    Picker("Max Age", selection: Binding.asyncValue(
                        get: { siteTLSViewModel.edgeTLSSettings.hsts.maxAge },
                        set: { age in
                            var updated = siteTLSViewModel.edgeTLSSettings.hsts
                            updated.maxAge = age
                            await siteTLSViewModel.updateHSTSSettings(updated)
                        }
                    )) {
                        Text("1 Month").tag(2_592_000)
                        Text("3 Months").tag(7_776_000)
                        Text("6 Months").tag(15_552_000)
                        Text("1 Year").tag(31_536_000)
                    }

                    Toggle("Include Subdomains", isOn: Binding.asyncValue(
                        get: { siteTLSViewModel.edgeTLSSettings.hsts.includeSubdomains },
                        set: { val in
                            var updated = siteTLSViewModel.edgeTLSSettings.hsts
                            updated.includeSubdomains = val
                            await siteTLSViewModel.updateHSTSSettings(updated)
                        }
                    ))

                    Toggle("Preload", isOn: Binding.asyncValue(
                        get: { siteTLSViewModel.edgeTLSSettings.hsts.preload },
                        set: { val in
                            var updated = siteTLSViewModel.edgeTLSSettings.hsts
                            updated.preload = val
                            await siteTLSViewModel.updateHSTSSettings(updated)
                        }
                    ))

                    Toggle("No-Sniff Header", isOn: Binding.asyncValue(
                        get: { siteTLSViewModel.edgeTLSSettings.hsts.nosniff },
                        set: { val in
                            var updated = siteTLSViewModel.edgeTLSSettings.hsts
                            updated.nosniff = val
                            await siteTLSViewModel.updateHSTSSettings(updated)
                        }
                    ))
                }
            } header: {
                Text("HSTS")
            }
        }
        .navigationTitle("SSL/TLS")
        .disabled(siteTLSViewModel.selectedZoneID == nil || siteTLSViewModel.isRefreshingZoneControls)
        .task(id: siteTLSViewModel.selectedZoneID) {
            guard let zoneID = siteTLSViewModel.selectedZoneID else { return }
            if siteTLSViewModel.isTLSLoaded(for: zoneID) == false {
                do {
                    try await siteTLSViewModel.refreshTLSPageData()
                } catch {
                    siteTLSViewModel.presentError(error)
                }
            }
            if siteTLSViewModel.isHSTSLoaded(for: zoneID) == false {
                do {
                    try await siteTLSViewModel.refreshHSTSSettings()
                } catch {
                    siteTLSViewModel.presentError(error)
                }
            }
        }
        .refreshable {
            do {
                try await siteTLSViewModel.refreshTLSPageData(force: true)
            } catch {
                siteTLSViewModel.presentError(error)
            }
            do {
                try await siteTLSViewModel.refreshHSTSSettings(force: true)
            } catch {
                siteTLSViewModel.presentError(error)
            }
        }
    }

}

struct SiteCachingView: View {
    @Environment(SiteCachingViewModel.self) private var siteCachingViewModel

    var body: some View {
        Form {
            Section("Caching Controls") {
                ZoneControlRow(
                    title: ZoneControlToggle.developmentMode.title,
                    detail: ZoneControlToggle.developmentMode.description,
                    isOn: Binding.asyncValue(
                        get: { siteCachingViewModel.zoneControls.developmentMode },
                        set: { newValue in
                            await siteCachingViewModel.updateZoneControl(.developmentMode, enabled: newValue)
                        }
                    )
                )

                ZoneControlRow(
                    title: ZoneControlToggle.alwaysOnline.title,
                    detail: ZoneControlToggle.alwaysOnline.description,
                    isOn: Binding.asyncValue(
                        get: { siteCachingViewModel.zoneControls.alwaysOnline },
                        set: { newValue in
                            await siteCachingViewModel.updateZoneControl(.alwaysOnline, enabled: newValue)
                        }
                    )
                )
            }

            Section("Cache Level") {
                ForEach(CacheLevel.allCases) { level in
                    ZoneControlRow(
                        title: level.title,
                        detail: level.description,
                        isOn: Binding.asyncValue(
                            get: { siteCachingViewModel.zoneCacheSettings.cacheLevel == level },
                            set: { selected in
                                if selected { await siteCachingViewModel.updateCacheLevel(level) }
                            }
                        )
                    )
                }
            }

            Section("Browser Cache TTL") {
                Picker("TTL", selection: Binding.asyncValue(
                    get: { siteCachingViewModel.zoneCacheSettings.browserCacheTTL },
                    set: { ttl in await siteCachingViewModel.updateBrowserCacheTTL(ttl) }
                )) {
                    ForEach(ZoneCacheSettings.browserCacheTTLOptions, id: \.self) { ttl in
                        Text(ZoneCacheSettings.formatTTL(ttl)).tag(ttl)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Caching")
        .disabled(siteCachingViewModel.selectedZoneID == nil || siteCachingViewModel.isRefreshingZoneControls)
        .task(id: siteCachingViewModel.selectedZoneID) {
            guard let zoneID = siteCachingViewModel.selectedZoneID else { return }
            guard siteCachingViewModel.isLoaded(for: zoneID) == false else { return }
            do {
                try await siteCachingViewModel.refreshCachingPageData()
            } catch {
                siteCachingViewModel.presentError(error)
            }
        }
        .refreshable {
            do {
                try await siteCachingViewModel.refreshCachingPageData(force: true)
            } catch {
                siteCachingViewModel.presentError(error)
            }
        }
    }

}
