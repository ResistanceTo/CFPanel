import Foundation
import SwiftUI

nonisolated enum AuthTokenMode: String, CaseIterable, Identifiable, Codable {
    case account

    var id: String {
        rawValue
    }

    var title: LocalizedStringResource {
        "Account Token"
    }

    var description: LocalizedStringResource {
        "Created from Manage Account > API Tokens and verified with an account ID."
    }
}

nonisolated enum AuthenticationMethod: String, CaseIterable, Identifiable, Codable {
    case accountToken
    case oauth

    var id: String {
        rawValue
    }

    var title: LocalizedStringResource {
        switch self {
        case .accountToken:
            "Account Token"
        case .oauth:
            "Cloudflare OAuth"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .accountToken:
            "Paste an account token and the matching account ID."
        case .oauth:
            "Authorize in the browser with Cloudflare OAuth 2.0."
        }
    }
}

nonisolated enum CredentialStorageMode: String, CaseIterable, Identifiable, Codable {
    case local

    static let defaultsKey = "credential_storage_mode"

    var id: String {
        rawValue
    }

    static var persistedDefault: CredentialStorageMode {
        let rawValue = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
        return CredentialStorageMode(rawValue: rawValue) ?? .local
    }

    func persistAsDefault() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }

    var title: LocalizedStringResource {
        switch self {
        case .local: "This Device"
        }
    }

    var shortTitle: LocalizedStringResource {
        switch self {
        case .local: "Local"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .local:
            "Stores the Cloudflare token only on this device."
        }
    }
}

nonisolated enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case sites
    case security
    case account
    case settings

    var id: String {
        rawValue
    }

    var title: LocalizedStringResource {
        switch self {
        case .dashboard: "Monitor"
        case .sites: "Sites"
        case .security: "Security"
        case .account: "Platform"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "waveform.path.ecg"
        case .sites: "globe"
        case .security: "shield.lefthalf.filled"
        case .account: "shippingbox"
        case .settings: "gearshape"
        }
    }
}

nonisolated enum AccountDataProduct: String, CaseIterable, Identifiable, Hashable {
    case kv
    case r2
    case d1
    case queues
    case vectorize
    case hyperdrive

    var id: String {
        rawValue
    }

    var title: LocalizedStringResource {
        switch self {
        case .kv: "KV"
        case .r2: "R2"
        case .d1: "D1"
        case .queues: "Queues"
        case .vectorize: "Vectorize"
        case .hyperdrive: "Hyperdrive"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .kv:
            "Namespaces and key browsing."
        case .r2:
            "Buckets and object storage regions."
        case .d1:
            "SQLite databases and storage metrics."
        case .queues:
            "Message queues, producers, and consumers."
        case .vectorize:
            "Vector indexes and metadata indexes."
        case .hyperdrive:
            "Database acceleration configs and origin settings."
        }
    }

    var systemImage: String {
        switch self {
        case .kv: "shippingbox.circle"
        case .r2: "externaldrive"
        case .d1: "cylinder.split.1x2"
        case .queues: "point.3.filled.connected.trianglepath.dotted"
        case .vectorize: "sparkles.rectangle.stack"
        case .hyperdrive: "bolt.horizontal.circle"
        }
    }
}
