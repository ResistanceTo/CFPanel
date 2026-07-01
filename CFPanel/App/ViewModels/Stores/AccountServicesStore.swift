import Foundation
import Observation

@MainActor
@Observable
final class AccountServicesStore {
    var pagesProjects: [PagesProject] = []
    var workerRuntimes: [WorkerRuntimeSummary] = []
    var workersUsage: WorkersUsageSnapshot?
    var r2Buckets: [R2Bucket] = []
    var d1Databases: [D1Database] = []
    var queues: [QueueSummary] = []
    var kvNamespaces: [KVNamespace] = []
    var vectorizeIndexes: [VectorizeIndex] = []
    var hyperdriveConfigs: [HyperdriveConfig] = []

    var pagesStatusMessage: String?
    var workersStatusMessage: String?
    var workersUsageStatusMessage: String?
    var r2StatusMessage: String?
    var d1StatusMessage: String?
    var queuesStatusMessage: String?
    var kvStatusMessage: String?
    var vectorizeStatusMessage: String?
    var hyperdriveStatusMessage: String?

    func reset(statusMessage: String? = nil) {
        pagesProjects = []
        workerRuntimes = []
        workersUsage = nil
        r2Buckets = []
        d1Databases = []
        queues = []
        kvNamespaces = []
        vectorizeIndexes = []
        hyperdriveConfigs = []
        pagesStatusMessage = statusMessage
        workersStatusMessage = statusMessage
        workersUsageStatusMessage = statusMessage
        r2StatusMessage = statusMessage
        d1StatusMessage = statusMessage
        queuesStatusMessage = statusMessage
        kvStatusMessage = statusMessage
        vectorizeStatusMessage = statusMessage
        hyperdriveStatusMessage = statusMessage
    }

    func clearPages(statusMessage: String) {
        pagesProjects = []
        pagesStatusMessage = statusMessage
    }

    func clearWorkers(statusMessage: String) {
        workerRuntimes = []
        workersUsage = nil
        workersStatusMessage = statusMessage
        workersUsageStatusMessage = statusMessage
    }

    func clearProduct(_ product: AccountDataProduct, statusMessage: String) {
        switch product {
        case .kv:
            kvNamespaces = []
            kvStatusMessage = statusMessage
        case .r2:
            r2Buckets = []
            r2StatusMessage = statusMessage
        case .d1:
            d1Databases = []
            d1StatusMessage = statusMessage
        case .queues:
            queues = []
            queuesStatusMessage = statusMessage
        case .vectorize:
            vectorizeIndexes = []
            vectorizeStatusMessage = statusMessage
        case .hyperdrive:
            hyperdriveConfigs = []
            hyperdriveStatusMessage = statusMessage
        }
    }
}
