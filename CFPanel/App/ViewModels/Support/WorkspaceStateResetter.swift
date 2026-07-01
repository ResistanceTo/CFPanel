import Foundation

enum WorkspaceStateResetter {
    @MainActor
    static func resetZoneScopedState(
        zoneStore: ZoneWorkspaceStore,
        dnsStore: DNSStore,
        emailRoutingStore: EmailRoutingStore,
        emailSendingStore: EmailSendingStore,
        rulesStore: RulesStore,
        accountStore: AccountServicesStore,
        loadStateStore: ResourceLoadStateStore
    ) {
        zoneStore.resetZoneScopedState()
        dnsStore.reset()
        emailRoutingStore.resetZoneScopedState()
        emailSendingStore.resetZoneScopedState()
        loadStateStore.resetZoneScopedState()
        resetAccountScopedState(
            accountStore: accountStore,
            emailRoutingStore: emailRoutingStore,
            loadStateStore: loadStateStore
        )
        resetRulesState(
            rulesStore: rulesStore,
            loadStateStore: loadStateStore
        )
    }

    @MainActor
    static func resetAccountScopedState(
        accountStore: AccountServicesStore,
        emailRoutingStore: EmailRoutingStore,
        loadStateStore: ResourceLoadStateStore,
        statusMessage: String? = nil
    ) {
        accountStore.reset(statusMessage: statusMessage)
        emailRoutingStore.resetAccountScopedState(statusMessage: statusMessage)
        loadStateStore.resetAccountScopedState()
    }

    @MainActor
    static func resetRulesState(
        rulesStore: RulesStore,
        loadStateStore: ResourceLoadStateStore
    ) {
        rulesStore.reset()
        loadStateStore.resetRulesState()
    }
}
