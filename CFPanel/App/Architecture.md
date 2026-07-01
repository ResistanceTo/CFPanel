# CFPanel App Architecture

CFPanel uses a lightweight MVVM layout around SwiftUI Observation.

## Directory Shape

- `App/Root`: app entry and root navigation shell.
- `App/AppContainer.swift`: app-wide composition root that owns `AppStores` and wires feature view models.
- `App/ViewModels`: app shell model, shared observable stores, and cross-feature support utilities.
- `App/ViewModels/Stores`: `AppStores` plus observable business stores that own mutable UI state.
- `App/ViewModels/Support`: shared view-model support types such as shell actions, request contexts, and load-state keys.
- `Domain/Models`: Cloudflare domain models and UI-safe value projections.
- `Core/Networking`: Cloudflare API transport and endpoint clients.
- `Core/Storage`: Keychain and iCloud preference storage.
- `Features`: SwiftUI views grouped by product area (`Monitor`, `Sites`, `Security`, `Account`, `Pages`,
  `Workers`, `DataServices`, `Mail`, `DNS`, `Rules`, `PanicCenter`, `Settings`, and shared `Common` views).

## ViewModel Responsibilities

`AppModel` is now the app shell model. It owns root tab selection, global alerts, logging, and unauthorized-session
handoff only. It does not own Cloudflare API clients, feature request orchestration, or mutable business stores.
Feature views should not read Cloudflare business state from `AppModel`; they should depend on a feature-specific
view model injected by `AppContainer`.

`AppStores` is the app-wide business state container. It is created by `AppContainer` and holds the shared stores that
must be coordinated across feature view models. This keeps cross-feature state visible at the composition root without
making `AppModel` a business-state facade.

`AppShellActions` is the narrow bridge from feature view models back to app-shell concerns: global alerts, logging, and
root tab selection. Feature modules receive this bridge instead of receiving `AppModel` or several unrelated closure
parameters.

- `AuthSessionStore`: token mode, token input, credential storage, session revision, API session version.
- `ZoneWorkspaceStore`: selected zone, zone list, dashboard, zone settings, panic/security state.
- `DNSStore`: DNS records, filters, editor draft, cached DNS derived state.
- `EmailRoutingStore`: Email Routing settings, DNS status, rules, catch-all, and destination addresses.
- `EmailSendingStore`: Email Sending subdomain catalog state.
- `RulesStore`: Ruleset phase state and inventory summary cache.
- `AccountServicesStore`: Pages, Workers, R2, D1, Queues, KV, Vectorize, and Hyperdrive catalogs.
- `LoadingStateStore`: loading flags derived from counted activities.
- `ResourceLoadStateStore`: "already loaded" keys for zone/account/rules resources.

Request orchestration should live in the feature or domain owner, not in `AppModel`. `AppContainer` wires `AppStores`
and `AppShellActions` into each feature view model.

Authentication is split into view-state orchestration and services:

- `Features/Authentication/AuthenticationViewModel.swift`: authentication form state, bootstrap/sign-in/sign-out
  orchestration, token verification, and unauthorized-session invalidation.
- `Features/Authentication/CredentialPersistenceService.swift`: Keychain credential loading, migration, persistence,
  storage-mode migration, and deletion.
- `Features/Authentication/AuthenticatedWorkspaceLoader.swift`: initial authenticated zone list loading and preferred
  zone selection.

Sites have been migrated to `Features/Sites/SitesViewModel.swift`, which owns zone list refresh, selected-zone
switching, and workspace refresh.

Monitor is split by activity surface:

- `Features/Monitor/DashboardWorkspaceContext.swift`: shared selected-zone/account context, dashboard loading state,
  stale-response checks, and shell actions.
- `Features/Monitor/DashboardHomeViewModel.swift`: monitor home, zone details, dashboard analytics, and dashboard
  range refreshes.
- `Features/Monitor/AuditLogViewModel.swift`: account audit log pagination and scope filtering.

DNS is split by zone DNS workflow:

- `Features/DNS/DNSWorkspaceContext.swift`: shared selected-zone context, DNS loading state, stale-response checks,
  and shell actions.
- `Features/DNS/DNSRecordsViewModel.swift`: DNS record list, filters, editor draft, refresh, create/update/delete.
- `Features/DNS/DNSDiscoveryViewModel.swift`: DNS scan trigger, discovered record loading, and scan review accept/reject.
- `Features/DNS/DNSZoneFileViewModel.swift`: BIND zone file export/import.

Account-level Cloudflare products are split by product area:

- `Features/Account/AccountContextViewModel.swift`: account context display for the platform shell.
- `Features/Account/AccountServicesContext.swift`: shared account ID resolution, load-state coordination, loading
  activity tracking, and stale-response checks for account-level product view models.
- `Features/Pages/PagesCatalogViewModel.swift`: Pages project catalog and account-level Pages load state.
- `Features/Pages/PagesDeploymentsViewModel.swift`: Pages deployment history and retry/rollback/delete actions.
- `Features/Pages/PagesDomainsViewModel.swift`: Pages custom domains and validation retry/delete actions.
- `Features/Pages/PagesDeploymentLogsViewModel.swift`: Pages deployment logs.
- `Features/Pages/PagesOperationsViewModel.swift`: Pages build-cache purge and project deletion.
- `Features/Workers/WorkersCatalogViewModel.swift`: Workers script catalog and account-level Workers load state.
- `Features/Workers/WorkerExposureViewModel.swift`: workers.dev exposure, Worker routes, and custom domains.
- `Features/Workers/WorkerReleasesViewModel.swift`: Worker deployments and version list.
- `Features/Workers/WorkerRuntimeConfigurationViewModel.swift`: Worker settings and cron triggers.
- `Features/Workers/WorkerVersionsViewModel.swift`: Worker version detail loading.
- `Features/DataServices/DataServicesOverviewViewModel.swift`: account context display for the data-services entry.
- `Features/DataServices/KVViewModel.swift`: KV namespaces, key listing, value reads/writes, and bulk operations.
- `Features/DataServices/R2ViewModel.swift`: R2 bucket catalog and bucket detail loading.
- `Features/DataServices/D1ViewModel.swift`: D1 database catalog and database detail loading.
- `Features/DataServices/QueuesViewModel.swift`: Queues catalog and queue detail loading.
- `Features/DataServices/VectorizeViewModel.swift`: Vectorize index catalog, index detail, and metadata indexes.
- `Features/DataServices/HyperdriveViewModel.swift`: Hyperdrive config catalog and config detail loading.

Mail is split by Cloudflare mail product:

- `Features/Mail/EmailWorkspaceContext.swift`: shared zone context, account resolution, load-state coordination, and
  mail loading activity.
- `Features/Mail/EmailRoutingViewModel.swift`: Email Routing settings, DNS checks, routing rules, destination
  addresses, and catch-all updates.
- `Features/Mail/EmailSendingViewModel.swift`: Email Sending subdomain catalog and sending DNS record loading.

Rules and Policies are split by ruleset responsibility:

- `Features/Rules/RulesWorkspaceContext.swift`: shared selected-zone context, rules loading state, stale-response
  checks, and shell actions.
- `Features/Rules/RulesPhaseCatalogViewModel.swift`: phase inventory, entry-point ruleset loading, and phase state.
- `Features/Rules/RulesetDetailViewModel.swift`: referenced ruleset loading.
- `Features/Rules/RulesMutationViewModel.swift`: rule enable/disable, add, and delete operations.

Security and incident response are split by operational concern:

- `Features/Security/SecurityWorkspaceContext.swift`: shared selected-zone context, security loading state, and shell
  actions.
- `Features/Security/SecurityLevelViewModel.swift`: security level loading, security level updates, and Under Attack Mode.
- `Features/Security/CachePurgeViewModel.swift`: purge everything and custom URL cache purge actions.

Zone settings are split by settings surface:

- `Features/Sites/ZoneSettingsContext.swift`: shared selected-zone context, stale-response checks, load-state
  coordination, and zone-controls loading activity.
- `Features/Sites/ZoneSettingsDirectoryViewModel.swift`: the Settings directory entry.
- `Features/Sites/SiteOverviewViewModel.swift`: zone overview and pause/resume.
- `Features/Sites/SiteDNSSettingsViewModel.swift`: zone DNS settings.
- `Features/Sites/SiteTLSViewModel.swift`: SSL mode, minimum TLS version, HTTPS toggles, and HSTS.
- `Features/Sites/SiteCachingViewModel.swift`: Development Mode, Always Online, cache level, and browser cache TTL.
- `Features/Sites/ZoneTrafficControlsViewModel.swift`: traffic-related zone toggles.
- `Features/Sites/ZoneSecurityControlsViewModel.swift`: security-related zone toggles.
- `Features/Sites/ZoneEdgeFeaturesViewModel.swift`: HTTP/3, TLS 1.3, WebSockets, 0-RTT, geolocation, and WebP.

## Migration Rule

New feature work should prefer feature-specific view models or stores over adding raw state or business methods to
`AppModel`. Keep `AppModel` focused on app-level navigation shell, alerts, logging, and unauthorized-session handoff.

When a feature view becomes large, create a local view model next to that feature and keep Cloudflare request
orchestration in the feature view model or a dedicated service. Use `AppShellActions` for shell concerns such as
global alerts, logging, and tab changes instead of passing `AppModel` through feature modules.
