import Foundation
import Security

/// Small keychain wrapper used to persist Mercado Libre OAuth credentials securely.
struct KeychainStore {
    /// Keychain service name used to namespace the stored item.
    let service: String
    /// Keychain account name used to distinguish stored credentials.
    let account: String

    /// Loads the stored keychain payload when present.
    /// - Returns: Raw data for the current service/account pair, or `nil` when no item exists.
    func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    /// Saves or updates the keychain payload for the configured service/account pair.
    /// - Parameter data: Raw data to persist.
    func save(_ data: Data) throws {
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var creationQuery = baseQuery
            creationQuery[kSecValueData as String] = data

            let creationStatus = SecItemAdd(creationQuery as CFDictionary, nil)
            guard creationStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(creationStatus)
            }
        default:
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }
    }

    /// Deletes the stored keychain payload when present.
    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    /// Base query shared by load, save, and delete operations.
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

/// Keychain-specific failures surfaced by `KeychainStore`.
enum KeychainStoreError: Error, Equatable, Sendable {
    /// Security framework returned an unexpected OSStatus code.
    case unexpectedStatus(OSStatus)
}
