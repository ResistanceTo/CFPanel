import Foundation

@MainActor
final class AppStores {
    let auth = AuthSessionStore()
    let zoneWorkspace = ZoneWorkspaceStore()
    let dns = DNSStore()
    let emailRouting = EmailRoutingStore()
    let emailSending = EmailSendingStore()
    let rules = RulesStore()
    let accountServices = AccountServicesStore()
    let loading = LoadingStateStore()
    let loadState = ResourceLoadStateStore()
}
