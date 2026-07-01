//
//  CFPanelApp.swift
//  CFPanel
//
//  Created by ResistanceTo on 2026-03-11.
//

import SwiftUI

@main
struct CFPanelApp: App {
    @State private var appContainer = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appContainer.appModel)
                .environment(appContainer.authenticationViewModel)
                .environment(appContainer.dnsRecordsViewModel)
                .environment(appContainer.dnsDiscoveryViewModel)
                .environment(appContainer.dnsZoneFileViewModel)
                .environment(appContainer.emailRoutingViewModel)
                .environment(appContainer.emailSendingViewModel)
                .environment(appContainer.rulesPhaseCatalogViewModel)
                .environment(appContainer.rulesetDetailViewModel)
                .environment(appContainer.rulesMutationViewModel)
                .environment(appContainer.securityLevelViewModel)
                .environment(appContainer.cachePurgeViewModel)
                .environment(appContainer.zoneSettingsDirectoryViewModel)
                .environment(appContainer.siteOverviewViewModel)
                .environment(appContainer.siteDNSSettingsViewModel)
                .environment(appContainer.siteTLSViewModel)
                .environment(appContainer.siteCachingViewModel)
                .environment(appContainer.zoneTrafficControlsViewModel)
                .environment(appContainer.zoneSecurityControlsViewModel)
                .environment(appContainer.zoneEdgeFeaturesViewModel)
                .environment(appContainer.dashboardHomeViewModel)
                .environment(appContainer.auditLogViewModel)
                .environment(appContainer.sitesViewModel)
                .environment(appContainer.accountContextViewModel)
                .environment(appContainer.pagesCatalogViewModel)
                .environment(appContainer.pagesDeploymentsViewModel)
                .environment(appContainer.pagesDomainsViewModel)
                .environment(appContainer.pagesDeploymentLogsViewModel)
                .environment(appContainer.pagesOperationsViewModel)
                .environment(appContainer.workersCatalogViewModel)
                .environment(appContainer.workerExposureViewModel)
                .environment(appContainer.workerRuntimeConfigurationViewModel)
                .environment(appContainer.workerReleasesViewModel)
                .environment(appContainer.workerVersionsViewModel)
                .environment(appContainer.dataServicesOverviewViewModel)
                .environment(appContainer.kvViewModel)
                .environment(appContainer.r2ViewModel)
                .environment(appContainer.d1ViewModel)
                .environment(appContainer.queuesViewModel)
                .environment(appContainer.vectorizeViewModel)
                .environment(appContainer.hyperdriveViewModel)
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .cfpanelOAuthCallbackReceived,
                        object: url
                    )
                }
        }
    }
}
