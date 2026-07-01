import Foundation

@MainActor
struct AppCompositionContexts {
    let accountServices: AccountServicesContext
    let emailWorkspace: EmailWorkspaceContext
    let zoneSettings: ZoneSettingsContext
    let dnsWorkspace: DNSWorkspaceContext
    let rulesWorkspace: RulesWorkspaceContext
    let securityWorkspace: SecurityWorkspaceContext
    let dashboardWorkspace: DashboardWorkspaceContext

    init(api: CloudflareAPI, stores: AppStores, shellActions: AppShellActions) {
        accountServices = AccountServicesContext(
            api: api,
            sessionStore: stores.auth,
            zoneStore: stores.zoneWorkspace,
            loadingStore: stores.loading,
            loadStateStore: stores.loadState,
            shellActions: shellActions
        )
        emailWorkspace = EmailWorkspaceContext(
            api: api,
            sessionStore: stores.auth,
            zoneStore: stores.zoneWorkspace,
            loadingStore: stores.loading,
            loadStateStore: stores.loadState,
            shellActions: shellActions
        )
        zoneSettings = ZoneSettingsContext(
            api: api,
            sessionStore: stores.auth,
            zoneStore: stores.zoneWorkspace,
            loadingStore: stores.loading,
            loadStateStore: stores.loadState,
            shellActions: shellActions
        )
        dnsWorkspace = DNSWorkspaceContext(
            api: api,
            sessionStore: stores.auth,
            zoneStore: stores.zoneWorkspace,
            loadingStore: stores.loading,
            loadStateStore: stores.loadState,
            shellActions: shellActions
        )
        rulesWorkspace = RulesWorkspaceContext(
            api: api,
            sessionStore: stores.auth,
            zoneStore: stores.zoneWorkspace,
            loadingStore: stores.loading,
            loadStateStore: stores.loadState,
            shellActions: shellActions
        )
        securityWorkspace = SecurityWorkspaceContext(
            api: api,
            sessionStore: stores.auth,
            zoneStore: stores.zoneWorkspace,
            loadingStore: stores.loading,
            loadStateStore: stores.loadState,
            shellActions: shellActions
        )
        dashboardWorkspace = DashboardWorkspaceContext(
            api: api,
            sessionStore: stores.auth,
            zoneStore: stores.zoneWorkspace,
            loadingStore: stores.loading,
            loadStateStore: stores.loadState,
            shellActions: shellActions
        )
    }
}

@MainActor
struct AuthenticationFeatureComposition {
    let viewModel: AuthenticationViewModel

    init(api: CloudflareAPI, stores: AppStores, shellActions: AppShellActions) {
        viewModel = AuthenticationViewModel(
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
    }
}

@MainActor
struct DNSFeatureComposition {
    let recordsViewModel: DNSRecordsViewModel
    let discoveryViewModel: DNSDiscoveryViewModel
    let zoneFileViewModel: DNSZoneFileViewModel

    init(context: DNSWorkspaceContext, stores: AppStores) {
        recordsViewModel = DNSRecordsViewModel(
            store: stores.dns,
            context: context
        )
        discoveryViewModel = DNSDiscoveryViewModel(
            recordsViewModel: recordsViewModel,
            context: context
        )
        zoneFileViewModel = DNSZoneFileViewModel(
            recordsViewModel: recordsViewModel,
            context: context
        )
    }
}

@MainActor
struct RulesFeatureComposition {
    let phaseCatalogViewModel: RulesPhaseCatalogViewModel
    let rulesetDetailViewModel: RulesetDetailViewModel
    let mutationViewModel: RulesMutationViewModel

    init(context: RulesWorkspaceContext, stores: AppStores) {
        phaseCatalogViewModel = RulesPhaseCatalogViewModel(
            store: stores.rules,
            context: context
        )
        rulesetDetailViewModel = RulesetDetailViewModel(context: context)
        mutationViewModel = RulesMutationViewModel(
            catalogViewModel: phaseCatalogViewModel,
            context: context
        )
    }
}

@MainActor
struct SecurityFeatureComposition {
    let securityLevelViewModel: SecurityLevelViewModel
    let cachePurgeViewModel: CachePurgeViewModel

    init(context: SecurityWorkspaceContext) {
        securityLevelViewModel = SecurityLevelViewModel(context: context)
        cachePurgeViewModel = CachePurgeViewModel(context: context)
    }
}

@MainActor
struct ZoneSettingsFeatureComposition {
    let directoryViewModel: ZoneSettingsDirectoryViewModel
    let overviewViewModel: SiteOverviewViewModel
    let dnsSettingsViewModel: SiteDNSSettingsViewModel
    let tlsViewModel: SiteTLSViewModel
    let cachingViewModel: SiteCachingViewModel
    let trafficControlsViewModel: ZoneTrafficControlsViewModel
    let securityControlsViewModel: ZoneSecurityControlsViewModel
    let edgeFeaturesViewModel: ZoneEdgeFeaturesViewModel

    init(context: ZoneSettingsContext) {
        directoryViewModel = ZoneSettingsDirectoryViewModel(context: context)
        overviewViewModel = SiteOverviewViewModel(context: context)
        dnsSettingsViewModel = SiteDNSSettingsViewModel(context: context)
        tlsViewModel = SiteTLSViewModel(context: context)
        cachingViewModel = SiteCachingViewModel(context: context)
        trafficControlsViewModel = ZoneTrafficControlsViewModel(context: context)
        securityControlsViewModel = ZoneSecurityControlsViewModel(context: context)
        edgeFeaturesViewModel = ZoneEdgeFeaturesViewModel(context: context)
    }
}

@MainActor
struct DashboardFeatureComposition {
    let homeViewModel: DashboardHomeViewModel
    let auditLogViewModel: AuditLogViewModel

    init(context: DashboardWorkspaceContext) {
        homeViewModel = DashboardHomeViewModel(context: context)
        auditLogViewModel = AuditLogViewModel(context: context)
    }
}

@MainActor
struct MailFeatureComposition {
    let emailRoutingViewModel: EmailRoutingViewModel
    let emailSendingViewModel: EmailSendingViewModel

    init(context: EmailWorkspaceContext, stores: AppStores) {
        emailRoutingViewModel = EmailRoutingViewModel(
            store: stores.emailRouting,
            loadingStore: stores.loading,
            context: context
        )
        emailSendingViewModel = EmailSendingViewModel(
            store: stores.emailSending,
            loadingStore: stores.loading,
            context: context
        )
    }
}

@MainActor
struct AccountFeatureComposition {
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

    init(context: AccountServicesContext, stores: AppStores) {
        accountContextViewModel = AccountContextViewModel(context: context)
        pagesCatalogViewModel = PagesCatalogViewModel(
            accountStore: stores.accountServices,
            loadingStore: stores.loading,
            context: context
        )
        pagesDeploymentsViewModel = PagesDeploymentsViewModel(context: context)
        pagesDomainsViewModel = PagesDomainsViewModel(context: context)
        pagesDeploymentLogsViewModel = PagesDeploymentLogsViewModel(context: context)
        pagesOperationsViewModel = PagesOperationsViewModel(context: context)
        workersCatalogViewModel = WorkersCatalogViewModel(
            accountStore: stores.accountServices,
            loadingStore: stores.loading,
            context: context
        )
        workerExposureViewModel = WorkerExposureViewModel(context: context)
        workerRuntimeConfigurationViewModel = WorkerRuntimeConfigurationViewModel(context: context)
        workerReleasesViewModel = WorkerReleasesViewModel(context: context)
        workerVersionsViewModel = WorkerVersionsViewModel(context: context)
        dataServicesOverviewViewModel = DataServicesOverviewViewModel(context: context)
        kvViewModel = KVViewModel(
            accountStore: stores.accountServices,
            loadingStore: stores.loading,
            context: context
        )
        r2ViewModel = R2ViewModel(
            accountStore: stores.accountServices,
            loadingStore: stores.loading,
            context: context
        )
        d1ViewModel = D1ViewModel(
            accountStore: stores.accountServices,
            loadingStore: stores.loading,
            context: context
        )
        queuesViewModel = QueuesViewModel(
            accountStore: stores.accountServices,
            loadingStore: stores.loading,
            context: context
        )
        vectorizeViewModel = VectorizeViewModel(
            accountStore: stores.accountServices,
            loadingStore: stores.loading,
            context: context
        )
        hyperdriveViewModel = HyperdriveViewModel(
            accountStore: stores.accountServices,
            loadingStore: stores.loading,
            context: context
        )
    }
}
