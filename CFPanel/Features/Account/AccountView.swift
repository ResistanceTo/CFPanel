import SwiftUI

struct AccountView: View {
    @Environment(AccountContextViewModel.self) private var accountContextViewModel
    @Environment(PagesCatalogViewModel.self) private var pagesCatalogViewModel
    @Environment(WorkersCatalogViewModel.self) private var workersCatalogViewModel
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                accountContextSection
                buildAndDeploySection
                computeSection
                dataServicesSection
            }
            .navigationTitle("Platform")
            .navigationDestination(for: AccountRoute.self) { route in
                accountDestination(for: route)
            }
            .navigationDestination(for: PagesProjectRoute.self) { route in
                pagesProjectDestination(for: route)
            }
            .navigationDestination(for: WorkerRuntimeRoute.self) { route in
                workerRuntimeDestination(for: route)
            }
        }
    }

    @ViewBuilder
    private func accountDestination(for route: AccountRoute) -> some View {
        switch route {
        case .pages:
            PagesCatalogView()
        case .workers:
            WorkersCatalogView()
        case .storageData:
            DataServicesView()
        }
    }

    @ViewBuilder
    private func pagesProjectDestination(for route: PagesProjectRoute) -> some View {
        if let project = pagesCatalogViewModel.pagesProject(id: route.projectID) {
            switch route.destination {
            case .detail:
                PagesProjectDetailView(project: project)
            case .deployments:
                PagesProjectDeploymentsView(project: project)
            case .domains:
                PagesProjectDomainsView(project: project)
            case .operations:
                PagesProjectOperationsView(project: project) {
                    popToPagesCatalog()
                }
            }
        } else {
            ContentUnavailableView(
                "Pages Project Not Available",
                systemImage: "doc.richtext",
                description: Text("Refresh Pages and try again.")
            )
        }
    }

    private func popToPagesCatalog() {
        var nextPath = NavigationPath()
        nextPath.append(AccountRoute.pages)
        path = nextPath
    }

    @ViewBuilder
    private func workerRuntimeDestination(for route: WorkerRuntimeRoute) -> some View {
        if let runtime = workersCatalogViewModel.workerRuntime(id: route.scriptID) {
            switch route.destination {
            case .detail:
                WorkerRuntimeDetailView(runtime: runtime)
            case .exposureManagement:
                WorkerExposureManagementView(runtime: runtime)
            case .releases:
                WorkerRuntimeReleasesView(runtime: runtime)
            case .runtimeConfiguration:
                WorkerRuntimeConfigurationView(runtime: runtime)
            }
        } else {
            ContentUnavailableView(
                "Worker Not Available",
                systemImage: "shippingbox",
                description: Text("Refresh Workers and try again.")
            )
        }
    }

    private var accountContextSection: some View {
        Section("Account Overview") {
            if let accountID = accountContextViewModel.resolvedAccountID {
                LabeledContent {
                    Text(accountID)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("Account ID")
                }
            } else {
                Text("No account context is available for the current token.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var buildAndDeploySection: some View {
        Section {
            Text("Start here for deployable web properties and release-oriented workflows tied to your Cloudflare account.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink(value: AccountRoute.pages) {
                CompactNavigationRow(
                    title: "Pages",
                    subtitle: "Projects, deployments, domains, and project-level operations.",
                    systemImage: "doc.richtext"
                )
            }
        } header: {
            Text("Build & Deploy")
        }
    }

    private var computeSection: some View {
        Section {
            Text("Open this section for serverless runtimes, routing exposure, rollout history, and runtime configuration.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink(value: AccountRoute.workers) {
                CompactNavigationRow(
                    title: "Workers",
                    subtitle: "Scripts, exposure, releases, and runtime configuration.",
                    systemImage: "shippingbox"
                )
            }
        } header: {
            Text("Compute")
        }
    }

    private var dataServicesSection: some View {
        Section {
            Text("Open this area for stateful services such as object storage, databases, queues, and vector indexes.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            NavigationLink(value: AccountRoute.storageData) {
                CompactNavigationRow(
                    title: "Data Services",
                    subtitle: "KV, R2, D1, Queues, Vectorize, and Hyperdrive.",
                    systemImage: "internaldrive"
                )
            }
        } header: {
            Text("Data Services")
        }
    }
}

private enum AccountRoute: Hashable {
    case pages
    case workers
    case storageData
}

struct PagesProjectRoute: Hashable {
    let projectID: String
    let destination: Destination

    enum Destination: Hashable {
        case detail
        case deployments
        case domains
        case operations
    }
}

struct WorkerRuntimeRoute: Hashable {
    let scriptID: String
    let destination: Destination

    enum Destination: Hashable {
        case detail
        case exposureManagement
        case releases
        case runtimeConfiguration
    }
}

struct PagesCatalogView: View {
    @Environment(PagesCatalogViewModel.self) private var pagesCatalogViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                PagesStatusCard(
                    projects: pagesCatalogViewModel.pagesProjects,
                    message: pagesCatalogViewModel.pagesStatusMessage,
                    isRefreshing: pagesCatalogViewModel.isRefreshingPages
                )
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Pages")
        .task(id: pagesCatalogViewModel.resolvedAccountID) {
            guard let accountID = pagesCatalogViewModel.resolvedAccountID else { return }
            guard pagesCatalogViewModel.isPagesLoaded(for: accountID) == false else { return }
            await pagesCatalogViewModel.refreshPagesCatalog()
        }
        .refreshable {
            await pagesCatalogViewModel.refreshPagesCatalog(force: true)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.headline)
            Text("This view maps to the account-level Pages list in Cloudflare.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

struct WorkersCatalogView: View {
    @Environment(WorkersCatalogViewModel.self) private var workersCatalogViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                WorkersUsageCard(
                    usage: workersCatalogViewModel.workersUsage,
                    runtimeCount: workersCatalogViewModel.workerRuntimes.count,
                    message: workersCatalogViewModel.workersUsageStatusMessage,
                    isRefreshing: workersCatalogViewModel.isRefreshingWorkers
                )
                WorkersStatusCard(
                    runtimes: workersCatalogViewModel.workerRuntimes,
                    message: workersCatalogViewModel.workersStatusMessage,
                    isRefreshing: workersCatalogViewModel.isRefreshingWorkers
                )
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Workers")
        .task(id: workersCatalogViewModel.resolvedAccountID) {
            guard let accountID = workersCatalogViewModel.resolvedAccountID else { return }
            guard workersCatalogViewModel.isWorkersLoaded(for: accountID) == false else { return }
            await workersCatalogViewModel.refreshWorkersCatalog()
        }
        .refreshable {
            await workersCatalogViewModel.refreshWorkersCatalog(force: true)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scripts")
                .font(.headline)
            Text("Start with account-level usage, then drill into script inventory, routes, releases, and runtime details.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}
