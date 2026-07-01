import Foundation
import Observation

@MainActor
@Observable
final class LoadingStateStore {
    var isRefreshingDashboard = false
    var isRefreshingDNS = false
    var isPerformingPanicAction = false
    var isRefreshingZoneControls = false
    var isRefreshingMail = false
    var isRefreshingPlatformStatus = false
    var isRefreshingPages = false
    var isRefreshingWorkers = false
    var isRefreshingR2 = false
    var isRefreshingD1 = false
    var isRefreshingQueues = false
    var isRefreshingKV = false
    var isRefreshingVectorize = false
    var isRefreshingHyperdrive = false
    var isRefreshingRules = false

    @ObservationIgnored
    private var activityState = LoadingActivityState()

    func begin(_ activity: LoadingActivity) -> Int {
        let count = activityState.begin(activity)
        updateFlags()
        return count
    }

    func end(_ activity: LoadingActivity) -> Int {
        let count = activityState.end(activity)
        updateFlags()
        return count
    }

    private func updateFlags() {
        isRefreshingDashboard = activityState.isActive(.dashboard)
        isRefreshingDNS = activityState.isActive(.dns)
        isRefreshingMail = activityState.isActive(.mail)
        isRefreshingPages = activityState.isActive(.pages)
        isRefreshingWorkers = activityState.isActive(.workers)
        isRefreshingR2 = activityState.isActive(.r2)
        isRefreshingD1 = activityState.isActive(.d1)
        isRefreshingQueues = activityState.isActive(.queues)
        isRefreshingKV = activityState.isActive(.kv)
        isRefreshingVectorize = activityState.isActive(.vectorize)
        isRefreshingHyperdrive = activityState.isActive(.hyperdrive)
        isRefreshingPlatformStatus =
            isRefreshingPages
            || isRefreshingWorkers
            || isRefreshingR2
            || isRefreshingD1
            || isRefreshingQueues
            || isRefreshingKV
            || isRefreshingVectorize
            || isRefreshingHyperdrive
        isRefreshingZoneControls = activityState.isActive(.zoneControls)
        isRefreshingRules = activityState.isActive(.rules)
        isPerformingPanicAction = activityState.isActive(.panicAction)
    }
}
