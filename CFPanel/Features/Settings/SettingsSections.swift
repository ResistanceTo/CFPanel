import SwiftUI

struct SettingsConnectionSection: View {
    let authenticationMethod: AuthenticationMethod
    let credentialStorageMode: CredentialStorageMode
    let accountID: String
    let oauthAccountName: String
    let oauthGrantedScopes: [String]
    let tokenVerification: TokenVerification?
    let isUpdatingCredentialStorageMode: Bool
    let credentialStorageModeBinding: Binding<CredentialStorageMode>

    var body: some View {
        Section("Connection") {
            Picker("Token Storage", selection: credentialStorageModeBinding) {
                ForEach(CredentialStorageMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .disabled(isUpdatingCredentialStorageMode)

            if authenticationMethod == .oauth {
                LabeledContent("OAuth Account", value: oauthAccountName.isEmpty ? "Not Resolved" : oauthAccountName)
                if oauthGrantedScopes.isEmpty == false {
                    LabeledContent("OAuth Scopes", value: "\(oauthGrantedScopes.count)")
                }
            }

            LabeledContent {
                Text(accountID.isEmpty ? "Not Set" : accountID)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.middle)
            } label: {
                Text("Account ID")
            }

            if let tokenVerification {
                LabeledContent("Token Status", value: String(localized: tokenVerification.status.title))
                LabeledContent {
                    Text(tokenVerification.id.middleEllipsizedToken)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.middle)
                } label: {
                    Text("Token ID")
                }

                if let expiresOn = tokenVerification.expiresOn {
                    LabeledContent("Expires", value: expiresOn.formatted(date: .abbreviated, time: .shortened))
                }

                if let notBefore = tokenVerification.notBefore {
                    LabeledContent("Valid From", value: notBefore.formatted(date: .abbreviated, time: .shortened))
                }
            } else {
                Text(authenticationMethod == .oauth ? "No validated OAuth session is loaded." : "No validated token is loaded.")
                    .foregroundStyle(.secondary)
            }

            SettingsFootnote(authenticationMethod == .oauth ? "To change OAuth scopes, sign out and authorize again with a different permission set." : "To change account scope, sign out and reconnect with a different token.")
        }
    }
}

struct SettingsDangerousModeSection: View {
    let isUpdatingDangerousMode: Bool
    let errorMessage: String?
    let dangerousModeBinding: Binding<Bool>

    var body: some View {
        Section("Asset Protection") {
            Toggle("Advanced Dangerous Mode", isOn: dangerousModeBinding)
                .tint(.red)
                .disabled(isUpdatingDangerousMode)

            SettingsFootnote("When off, permanent delete controls are hidden. Turning it on requires device authentication; each delete still requires authentication and a confirmation countdown.")

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
