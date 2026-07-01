import Foundation

@MainActor
struct AppShellActions {
    let presentError: (Error) -> Void
    let presentErrorMessage: (String) -> Void
    let presentNotice: (String) -> Void
    let selectTab: (AppTab) -> Void
    let logDebug: (String) -> Void
    let logNotice: (String) -> Void
    let logError: (String) -> Void

    static func live(appModel: AppModel) -> AppShellActions {
        AppShellActions(
            presentError: { [weak appModel] error in
                appModel?.presentError(error)
            },
            presentErrorMessage: { [weak appModel] message in
                appModel?.presentError(message)
            },
            presentNotice: { [weak appModel] message in
                appModel?.presentNotice(message)
            },
            selectTab: { [weak appModel] tab in
                appModel?.selectedTab = tab
            },
            logDebug: { [weak appModel] message in
                appModel?.logDebug(message)
            },
            logNotice: { [weak appModel] message in
                appModel?.logNotice(message)
            },
            logError: { [weak appModel] message in
                appModel?.logError(message)
            }
        )
    }
}
