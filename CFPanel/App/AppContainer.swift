import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    let appModel: AppModel
    let stores: AppStores
    let authenticationViewModel: AuthenticationViewModel
    let dnsRecordsViewModel: DNSRecordsViewModel
    let dnsDiscoveryViewModel: DNSDiscoveryViewModel
    let dnsZoneFileViewModel: DNSZoneFileViewModel
    let accountContextViewModel: AccountContextViewModel
    let pagesCatalogViewModel: PagesCatalogViewModel
    let pagesDeploymentsViewModel: PagesDeploymentsViewModel
    let pagesDomainsViewModel: PagesDomainsViewModel
    let pagesDeploymentLogsViewModel: PagesDeploymentLogsViewModel
    let pagesOperationsViewModel: PagesOperationsViewModel
    let workersCatalogViewModel: WorkersCatalogViewModel
    let workerExposureViewModel: WorkerExposureViewModel
    let workerRuntimeConfigurationViewModel: WorkerRuntimeConfigurationViewModel
    let workerReleasesViewModel: WorkerReleasesViewModel
    let workerVersionsViewModel: WorkerVersionsViewModel
    let dataServicesOverviewViewModel: DataServicesOverviewViewModel
    let kvViewModel: KVViewModel
    let r2ViewModel: R2ViewModel
    let d1ViewModel: D1ViewModel
    let queuesViewModel: QueuesViewModel
    let vectorizeViewModel: VectorizeViewModel
    let hyperdriveViewModel: HyperdriveViewModel
    let emailRoutingViewModel: EmailRoutingViewModel
    let emailSendingViewModel: EmailSendingViewModel
    let rulesPhaseCatalogViewModel: RulesPhaseCatalogViewModel
    let rulesetDetailViewModel: RulesetDetailViewModel
    let rulesMutationViewModel: RulesMutationViewModel
    let securityLevelViewModel: SecurityLevelViewModel
    let cachePurgeViewModel: CachePurgeViewModel
    let zoneSettingsDirectoryViewModel: ZoneSettingsDirectoryViewModel
    let siteOverviewViewModel: SiteOverviewViewModel
    let siteDNSSettingsViewModel: SiteDNSSettingsViewModel
    let siteTLSViewModel: SiteTLSViewModel
    let siteCachingViewModel: SiteCachingViewModel
    let zoneTrafficControlsViewModel: ZoneTrafficControlsViewModel
    let zoneSecurityControlsViewModel: ZoneSecurityControlsViewModel
    let zoneEdgeFeaturesViewModel: ZoneEdgeFeaturesViewModel
    let dashboardHomeViewModel: DashboardHomeViewModel
    let auditLogViewModel: AuditLogViewModel
    let sitesViewModel: SitesViewModel

    init(api: CloudflareAPI = .shared) {
        let appModel = AppModel()
        let stores = AppStores()
        let shellActions = AppShellActions.live(appModel: appModel)
        let contexts = AppCompositionContexts(
            api: api,
            stores: stores,
            shellActions: shellActions
        )
        let authentication = AuthenticationFeatureComposition(api: api, stores: stores, shellActions: shellActions)
        let dns = DNSFeatureComposition(context: contexts.dnsWorkspace, stores: stores)
        let mail = MailFeatureComposition(context: contexts.emailWorkspace, stores: stores)
        let rules = RulesFeatureComposition(context: contexts.rulesWorkspace, stores: stores)
        let security = SecurityFeatureComposition(context: contexts.securityWorkspace)
        let zoneSettings = ZoneSettingsFeatureComposition(context: contexts.zoneSettings)
        let dashboard = DashboardFeatureComposition(context: contexts.dashboardWorkspace)
        let account = AccountFeatureComposition(context: contexts.accountServices, stores: stores)

        self.appModel = appModel
        self.stores = stores
        authenticationViewModel = authentication.viewModel
        Task {
            OAuthDiagnostics.notice("Registering OAuth token refresh handler with CloudflareAPI.")
            await api.setOAuthTokenRefreshHandler { @Sendable in
                guard let payload = try await OAuthTokenManager.shared.refreshPayloadIfNeeded() else {
                    OAuthDiagnostics.error("OAuth token refresh handler could not load a refreshable token payload.")
                    return nil
                }
                OAuthDiagnostics.notice(
                    "OAuth token refresh handler produced a valid access token expiring at \(OAuthDiagnostics.describeDate(payload.expiresAt))."
                )
                return payload.accessToken
            }
        }
        appModel.unauthorizedSessionHandler = { [weak authenticationViewModel] in
            authenticationViewModel?.invalidateSessionForUnauthorized()
        }
        dnsRecordsViewModel = dns.recordsViewModel
        dnsDiscoveryViewModel = dns.discoveryViewModel
        dnsZoneFileViewModel = dns.zoneFileViewModel
        emailRoutingViewModel = mail.emailRoutingViewModel
        emailSendingViewModel = mail.emailSendingViewModel
        rulesPhaseCatalogViewModel = rules.phaseCatalogViewModel
        rulesetDetailViewModel = rules.rulesetDetailViewModel
        rulesMutationViewModel = rules.mutationViewModel
        securityLevelViewModel = security.securityLevelViewModel
        cachePurgeViewModel = security.cachePurgeViewModel
        zoneSettingsDirectoryViewModel = zoneSettings.directoryViewModel
        siteOverviewViewModel = zoneSettings.overviewViewModel
        siteDNSSettingsViewModel = zoneSettings.dnsSettingsViewModel
        siteTLSViewModel = zoneSettings.tlsViewModel
        siteCachingViewModel = zoneSettings.cachingViewModel
        zoneTrafficControlsViewModel = zoneSettings.trafficControlsViewModel
        zoneSecurityControlsViewModel = zoneSettings.securityControlsViewModel
        zoneEdgeFeaturesViewModel = zoneSettings.edgeFeaturesViewModel
        dashboardHomeViewModel = dashboard.homeViewModel
        auditLogViewModel = dashboard.auditLogViewModel
        sitesViewModel = SitesViewModel(
            api: api,
            sessionStore: stores.auth,
            zoneStore: stores.zoneWorkspace,
            dnsStore: stores.dns,
            emailRoutingStore: stores.emailRouting,
            emailSendingStore: stores.emailSending,
            rulesStore: stores.rules,
            accountStore: stores.accountServices,
            loadStateStore: stores.loadState,
            shellActions: shellActions
        )
        accountContextViewModel = account.accountContextViewModel
        pagesCatalogViewModel = account.pagesCatalogViewModel
        pagesDeploymentsViewModel = account.pagesDeploymentsViewModel
        pagesDomainsViewModel = account.pagesDomainsViewModel
        pagesDeploymentLogsViewModel = account.pagesDeploymentLogsViewModel
        pagesOperationsViewModel = account.pagesOperationsViewModel
        workersCatalogViewModel = account.workersCatalogViewModel
        workerExposureViewModel = account.workerExposureViewModel
        workerRuntimeConfigurationViewModel = account.workerRuntimeConfigurationViewModel
        workerReleasesViewModel = account.workerReleasesViewModel
        workerVersionsViewModel = account.workerVersionsViewModel
        dataServicesOverviewViewModel = account.dataServicesOverviewViewModel
        kvViewModel = account.kvViewModel
        r2ViewModel = account.r2ViewModel
        d1ViewModel = account.d1ViewModel
        queuesViewModel = account.queuesViewModel
        vectorizeViewModel = account.vectorizeViewModel
        hyperdriveViewModel = account.hyperdriveViewModel
    }
}
