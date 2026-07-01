import Foundation
import Security

struct StoredCloudflareCredentials: Codable, Sendable {
    let token: String
    let tokenMode: AuthTokenMode
    let accountID: String
    let authenticationMethod: AuthenticationMethod
    let oauthAccountName: String?
    let oauthGrantedScopes: [String]?

    var normalizedAccountID: String {
        accountID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(
        token: String,
        tokenMode: AuthTokenMode,
        accountID: String,
        authenticationMethod: AuthenticationMethod = .accountToken,
        oauthAccountName: String? = nil,
        oauthGrantedScopes: [String]? = nil
    ) {
        self.token = token
        self.tokenMode = tokenMode
        self.accountID = accountID
        self.authenticationMethod = authenticationMethod
        self.oauthAccountName = oauthAccountName
        self.oauthGrantedScopes = oauthGrantedScopes
    }

    enum CodingKeys: String, CodingKey {
        case token
        case tokenMode
        case accountID
        case authenticationMethod
        case oauthAccountName
        case oauthGrantedScopes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        tokenMode = try container.decode(AuthTokenMode.self, forKey: .tokenMode)
        accountID = try container.decode(String.self, forKey: .accountID)
        authenticationMethod = try container.decodeIfPresent(AuthenticationMethod.self, forKey: .authenticationMethod) ?? .accountToken
        oauthAccountName = try container.decodeIfPresent(String.self, forKey: .oauthAccountName)
        oauthGrantedScopes = try container.decodeIfPresent([String].self, forKey: .oauthGrantedScopes)
    }
}

enum KeychainTokenStore {
    private static let legacyService = "org.zhaohe.CFPanel.cloudflare-token"
    private static let localService = "org.zhaohe.CFPanel.cloudflare-token.local"
    private static let syncedService = "org.zhaohe.CFPanel.cloudflare-token.synced"
    private static let account = "primary"

    static func save(
        credentials: StoredCloudflareCredentials,
        storageMode: CredentialStorageMode
    ) throws {
        let payload = try JSONEncoder().encode(credentials)
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service(for: storageMode),
            kSecAttrAccount: account,
            kSecAttrSynchronizable: synchronizableValue(for: storageMode),
            kSecAttrAccessible: accessibleValue(for: storageMode),
            kSecValueData: payload
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            // Update in place so a transient save failure does not delete the last good token first.
            let updateQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service(for: storageMode),
                kSecAttrAccount: account,
                kSecAttrSynchronizable: synchronizableValue(for: storageMode)
            ]
            let attributesToUpdate: [CFString: Any] = [
                kSecAttrAccessible: accessibleValue(for: storageMode),
                kSecValueData: payload
            ]
            let updateStatus = SecItemUpdate(
                updateQuery as CFDictionary,
                attributesToUpdate as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainTokenStoreError.unhandled(updateStatus)
            }
        default:
            throw KeychainTokenStoreError.unhandled(addStatus)
        }
    }

    static func loadCredentials(
        storageMode: CredentialStorageMode,
        fallbackMode: AuthTokenMode = .account,
        fallbackAccountID: String = ""
    ) throws -> StoredCloudflareCredentials? {
        guard let data = try loadData(
            service: service(for: storageMode),
            synchronizable: synchronizableValue(for: storageMode)
        ) else {
            return nil
        }

        return try decodeCredentials(
            from: data,
            fallbackMode: fallbackMode,
            fallbackAccountID: fallbackAccountID
        )
    }

    static func loadLegacyCredentials(
        fallbackMode: AuthTokenMode = .account,
        fallbackAccountID: String = ""
    ) throws -> StoredCloudflareCredentials? {
        let data = try loadData(service: legacyService, synchronizable: kSecAttrSynchronizableAny)
            ?? loadData(service: legacyService, synchronizable: kCFBooleanFalse as Any)

        guard let data else {
            return nil
        }

        return try decodeCredentials(
            from: data,
            fallbackMode: fallbackMode,
            fallbackAccountID: fallbackAccountID
        )
    }

    static func deleteCredentials(storageMode: CredentialStorageMode) throws {
        try deleteCredentials(
            service: service(for: storageMode),
            synchronizable: synchronizableValue(for: storageMode)
        )
    }

    static func deleteLegacyCredentials() throws {
        try deleteCredentials(service: legacyService, synchronizable: kSecAttrSynchronizableAny)
        try deleteCredentials(service: legacyService, synchronizable: kCFBooleanFalse as Any)
    }

    static func deleteAllCredentials() throws {
        try deleteCredentials(storageMode: .local)
        try deleteLegacyCredentials()
    }

    private static func decodeCredentials(
        from data: Data,
        fallbackMode: AuthTokenMode,
        fallbackAccountID: String
    ) throws -> StoredCloudflareCredentials {
        do {
            return try JSONDecoder().decode(StoredCloudflareCredentials.self, from: data)
        } catch let error as DecodingError {
            guard isLegacyTokenPayload(data),
                  let legacyToken = String(data: data, encoding: .utf8)
            else {
                throw error
            }

            return StoredCloudflareCredentials(
                token: legacyToken,
                tokenMode: fallbackMode,
                accountID: fallbackAccountID,
                authenticationMethod: .accountToken,
                oauthAccountName: nil,
                oauthGrantedScopes: nil
            )
        } catch {
            throw error
        }
    }

    private static func loadData(service: String, synchronizable: Any) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: synchronizable,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainTokenStoreError.invalidPayload
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainTokenStoreError.unhandled(status)
        }
    }

    private static func deleteCredentials(service: String, synchronizable: Any) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: synchronizable
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainTokenStoreError.unhandled(status)
        }
    }

    private static func service(for storageMode: CredentialStorageMode) -> String {
        switch storageMode {
        case .local:
            return localService
//            return syncedService
        }
    }

    private static func synchronizableValue(for storageMode: CredentialStorageMode) -> Any {
        switch storageMode {
        case .local:
            return kCFBooleanFalse as Any
//            return kCFBooleanTrue as Any
        }
    }

    private static func accessibleValue(for storageMode: CredentialStorageMode) -> CFString {
        switch storageMode {
        case .local:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
//            return kSecAttrAccessibleWhenUnlocked
        }
    }

    private static func isLegacyTokenPayload(_ data: Data) -> Bool {
        guard let payload = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            payload.isEmpty == false
        else {
            return false
        }

        guard let firstCharacter = payload.first else {
            return false
        }

        return firstCharacter != "{" && firstCharacter != "["
    }
}

enum KeychainTokenStoreError: LocalizedError {
    case invalidPayload
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "The saved Cloudflare credentials are invalid."
        case .unhandled(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}
