import Foundation
import Observation
import OSLog

private func isSilentCancellationError(_ error: Error) -> Bool {
    if error is CancellationError {
        return true
    }

    if let urlError = error as? URLError,
       urlError.code == .cancelled
    {
        return true
    }

    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue
}

@MainActor
@Observable
final class AppModel {
    var selectedTab: AppTab = .dashboard
    var alert: AppAlert?
    var unauthorizedSessionHandler: (() -> Void)?
    var suppressInterruptingErrorAlerts = false

    @ObservationIgnored
    let logger = Logger(subsystem: "org.zhaohe.CFPanel", category: "AppModel")
    @ObservationIgnored
    let verboseLoggingEnabled = ProcessInfo.processInfo.environment["CFPANEL_VERBOSE_LOGGING"] == "1"

    func presentError(_ error: Error) {
        if isSilentCancellationError(error) {
            logDebug("Ignored cancelled request.")
            return
        }

        if let apiError = error as? CloudflareAPIError,
           apiError == .unauthorized,
           unauthorizedSessionHandler != nil
        {
            unauthorizedSessionHandler?()
            logError("Unauthorized Cloudflare session detected. Local session will be invalidated.")
            return
        }

        logError("Request failed: \(error.localizedDescription)")
        if suppressInterruptingErrorAlerts {
            logDebug("Suppressed interrupting in-app error alert.")
            return
        }
        alert = AppAlert(
            title: "Request Failed",
            message: error.localizedDescription
        )
    }

    func presentError(_ message: String) {
        logError("Request failed: \(message)")
        if suppressInterruptingErrorAlerts {
            logDebug("Suppressed interrupting in-app error alert.")
            return
        }
        alert = AppAlert(title: "Request Failed", message: message)
    }

    func presentNotice(_ message: String) {
        logNotice(message)
        alert = AppAlert(title: "Done", message: message)
    }

    func logDebug(_ message: @autoclosure () -> String) {
        guard verboseLoggingEnabled else { return }
        let resolvedMessage = message()
        logger.debug("\(resolvedMessage, privacy: .public)")
    }

    func logNotice(_ message: @autoclosure () -> String) {
        guard verboseLoggingEnabled else { return }
        let resolvedMessage = message()
        logger.notice("\(resolvedMessage, privacy: .public)")
    }

    func logError(_ message: @autoclosure () -> String) {
        let resolvedMessage = message()
        logger.error("\(resolvedMessage, privacy: .public)")
    }
}
