import Foundation
import Observation

@MainActor
@Observable
final class ZoneSettingsDirectoryViewModel {
    @ObservationIgnored
    private let context: ZoneSettingsContext

    init(context: ZoneSettingsContext) {
        self.context = context
    }

    var selectedZoneID: String? { context.selectedZoneID }
    var selectedZone: CloudflareZone? { context.selectedZone }
}
