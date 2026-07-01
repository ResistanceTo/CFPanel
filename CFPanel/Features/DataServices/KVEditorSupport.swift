import Foundation

struct KVKeyDraft: Identifiable {
    let id = UUID()
    let existingKeyName: String?
    let keyName: String
    let value: String
    let metadataText: String
    let expirationMode: KVExpirationMode
    let expirationDate: Date
    let expirationTTLText: String

    var isEditingExistingKey: Bool {
        existingKeyName != nil
    }
}

struct KVBulkDraft: Identifiable {
    let id = UUID()
    let mode: KVBulkMode
    let payload: String
}

enum KVBulkMode: String, Identifiable {
    case write
    case delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .write:
            "Bulk Write"
        case .delete:
            "Bulk Delete"
        }
    }

    var actionTitle: String {
        switch self {
        case .write:
            "Run"
        case .delete:
            "Delete"
        }
    }

    var helpText: String {
        switch self {
        case .write:
            #"Paste a JSON array like [{"key":"a","value":"1","metadata":{"env":"prod"}},{"key":"b","value":"2","expiration_ttl":3600}]."#
        case .delete:
            "Paste one key per line to remove them from the namespace."
        }
    }
}

enum KVExpirationMode: String, CaseIterable, Identifiable {
    case none
    case ttl
    case absolute

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            "None"
        case .ttl:
            "TTL"
        case .absolute:
            "Date"
        }
    }
}
