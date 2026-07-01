import Foundation
import Observation

enum OAuthPermissionPreset: String, CaseIterable, Identifiable {
    case readOnly
    case readWrite

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .readOnly:
            "Read Only"
        case .readWrite:
            "Read / Write"
        }
    }
}

@MainActor
@Observable
final class OAuthSessionStore {
    var permissions: [OAuthFeaturePermission] = OAuthScopeCatalog.defaultPermissions.map { permission in
        var updatedPermission = permission
        updatedPermission.isEnabled = true
        updatedPermission.canEdit = false
        return updatedPermission
    }
    var isAuthorizing = false
    var statusMessage = ""
    var selectedPreset: OAuthPermissionPreset? = .readOnly

    @ObservationIgnored
    var pendingState: String?
    @ObservationIgnored
    var pendingCodeVerifier: String?

    var selectedScopes: [String] {
        OAuthScopeCatalog.buildScopeSet(from: permissions).sorted()
    }

    var scopeString: String {
        OAuthScopeCatalog.buildScopeString(from: permissions)
    }

    func togglePermission(_ permissionID: String) {
        guard let index = permissions.firstIndex(where: { $0.id == permissionID }) else { return }
        guard permissions[index].isRequired == false else { return }

        permissions[index].isEnabled.toggle()
        if permissions[index].isEnabled == false {
            permissions[index].canEdit = false
        }
        selectedPreset = matchingPreset()
    }

    func toggleEditPermission(_ permissionID: String) {
        guard let index = permissions.firstIndex(where: { $0.id == permissionID }) else { return }
        guard permissions[index].isEnabled, permissions[index].hasEditOption else { return }
        permissions[index].canEdit.toggle()
        selectedPreset = matchingPreset()
    }

    func applyPreset(_ preset: OAuthPermissionPreset) {
        permissions = permissions.map { permission in
            var updatedPermission = permission

            switch preset {
            case .readOnly:
                updatedPermission.isEnabled = true
                updatedPermission.canEdit = false
            case .readWrite:
                updatedPermission.isEnabled = true
                updatedPermission.canEdit = updatedPermission.hasEditOption
            }

            return updatedPermission
        }
        selectedPreset = preset
    }

    func resetPendingAuthorization() {
        pendingState = nil
        pendingCodeVerifier = nil
        isAuthorizing = false
        statusMessage = ""
    }

    private func matchingPreset() -> OAuthPermissionPreset? {
        let allEnabled = permissions.allSatisfy(\.isEnabled)
        guard allEnabled else { return nil }

        let allReadOnly = permissions.allSatisfy { permission in
            permission.canEdit == false
        }
        if allReadOnly {
            return .readOnly
        }

        let allReadWrite = permissions.allSatisfy { permission in
            permission.hasEditOption ? permission.canEdit : permission.canEdit == false
        }
        if allReadWrite {
            return .readWrite
        }

        return nil
    }
}
