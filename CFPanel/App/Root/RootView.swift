import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(AuthenticationViewModel.self) private var authenticationViewModel
    @AppStorage("pinned_zone_id") private var pinnedZoneID: String = ""
    @AppStorage("cloudflare_account_id") private var accountID: String = ""
    @State private var hasBootstrapped = false

    var body: some View {
        @Bindable var bindableAppModel = appModel

        Group {
            if hasBootstrapped == false || authenticationViewModel.isBootstrapping {
                bootstrappingView
            } else if authenticationViewModel.isSignedIn {
                mainTabs
            } else {
                AuthenticationView(pinnedZoneID: $pinnedZoneID)
            }
        }
        .onChange(of: authenticationViewModel.isSignedIn) {
            appModel.suppressInterruptingErrorAlerts = authenticationViewModel.isSignedIn
        }
        .task {
            guard hasBootstrapped == false else { return }
            hasBootstrapped = true
            appModel.suppressInterruptingErrorAlerts = false
            await authenticationViewModel.bootstrap(
                preferredZoneID: pinnedZoneID,
                fallbackTokenMode: .account,
                fallbackAccountID: accountID
            )
        }
        .alert(
            bindableAppModel.alert?.title ?? "",
            isPresented: .init(
                get: { bindableAppModel.alert != nil },
                set: { isPresented in
                    if isPresented == false {
                        bindableAppModel.alert = nil
                    }
                }
            ),
            presenting: bindableAppModel.alert
        ) { _ in
        } message: { alert in
            Text(alert.message)
        }
    }

    private var bootstrappingView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Connecting to Cloudflare")
                    .font(.headline)
                Text("Checking for a saved token and restoring your Cloudflare session.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var mainTabs: some View {
        @Bindable var appModel = appModel

        return TabView(selection: $appModel.selectedTab) {
            DashboardView()
                .tag(AppTab.dashboard)
                .tabItem {
                    Label {
                        Text(AppTab.dashboard.title)
                    } icon: {
                        Image(systemName: AppTab.dashboard.systemImage)
                    }
                }

            SitesView()
                .tag(AppTab.sites)
                .tabItem {
                    Label {
                        Text(AppTab.sites.title)
                    } icon: {
                        Image(systemName: AppTab.sites.systemImage)
                    }
                }

            SecurityView()
                .tag(AppTab.security)
                .tabItem {
                    Label {
                        Text(AppTab.security.title)
                    } icon: {
                        Image(systemName: AppTab.security.systemImage)
                    }
                }

            AccountView()
                .tag(AppTab.account)
                .tabItem {
                    Label {
                        Text(AppTab.account.title)
                    } icon: {
                        Image(systemName: AppTab.account.systemImage)
                    }
                }

            SettingsView()
                .tag(AppTab.settings)
                .tabItem {
                    Label {
                        Text(AppTab.settings.title)
                    } icon: {
                        Image(systemName: AppTab.settings.systemImage)
                    }
                }
        }
    }
}
