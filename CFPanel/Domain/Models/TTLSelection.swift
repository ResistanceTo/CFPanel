import SwiftUI

nonisolated enum TTLSelection: Int, CaseIterable, Identifiable, Codable {
    case automatic = 1
    case twoMinutes = 120
    case fiveMinutes = 300
    case oneHour = 3600
    case oneDay = 86_400

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic: "Auto"
        case .twoMinutes: "2 min"
        case .fiveMinutes: "5 min"
        case .oneHour: "1 Hour"
        case .oneDay: "1 Day"
        }
    }

    var displayTitle: String {
        switch self {
        case .automatic: "Auto"
        case .twoMinutes: "2 min"
        case .fiveMinutes: "5 min"
        case .oneHour: "1 Hour"
        case .oneDay: "1 Day"
        }
    }

    static func title(for ttl: Int) -> String {
        TTLSelection(rawValue: ttl)?.displayTitle ?? "\(ttl)s"
    }
}
