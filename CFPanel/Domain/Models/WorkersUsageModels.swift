import Foundation

nonisolated struct WorkersUsageSnapshot: Sendable {
    let requestsToday: Int
    let requestsMonth: Int
    let errorsMonth: Int
    let subrequestsMonth: Int
    let cpuTimeTodayUs: Double?
    let cpuTimeMonthUs: Double?
    let cpuP50Us: Double?
    let cpuP99Us: Double?

    static let empty = WorkersUsageSnapshot(
        requestsToday: 0,
        requestsMonth: 0,
        errorsMonth: 0,
        subrequestsMonth: 0,
        cpuTimeTodayUs: nil,
        cpuTimeMonthUs: nil,
        cpuP50Us: nil,
        cpuP99Us: nil
    )

    var requestQuotaEstimate: Int {
        100_000
    }

    var requestRemainingEstimate: Int {
        max(requestQuotaEstimate - requestsToday, 0)
    }

    var requestUsageRatio: Double {
        guard requestQuotaEstimate > 0 else { return 0 }
        return min(Double(requestsToday) / Double(requestQuotaEstimate), 1)
    }

    var errorRatePercent: Double? {
        guard requestsMonth > 0 else { return nil }
        return Double(errorsMonth) / Double(requestsMonth) * 100
    }

    var cpuTimeTodayMilliseconds: Double? {
        cpuTimeTodayUs.map { $0 / 1_000 }
    }

    var cpuTimeMonthMilliseconds: Double? {
        cpuTimeMonthUs.map { $0 / 1_000 }
    }
}
