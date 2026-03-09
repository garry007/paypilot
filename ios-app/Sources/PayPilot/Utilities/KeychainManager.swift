import Foundation

public enum KeychainManager {
    public static let accessTokenKey  = "paypilot.accessToken"
    public static let refreshTokenKey = "paypilot.refreshToken"

    @discardableResult
    public static func save(token: String, forKey key: String) -> Bool {
#if canImport(Security)
        return _keychainSave(token: token, forKey: key)
#else
        LinuxTokenStore.shared.store[key] = token
        return true
#endif
    }

    public static func load(key: String) -> String? {
#if canImport(Security)
        return _keychainLoad(key: key)
#else
        return LinuxTokenStore.shared.store[key]
#endif
    }

    @discardableResult
    public static func delete(key: String) -> Bool {
#if canImport(Security)
        return _keychainDelete(key: key)
#else
        LinuxTokenStore.shared.store.removeValue(forKey: key)
        return true
#endif
    }
}

// MARK: - Linux in-memory fallback
#if !canImport(Security)
final class LinuxTokenStore {
    static let shared = LinuxTokenStore()
    var store: [String: String] = [:]
    private init() {}
}
#endif

// MARK: - Apple Keychain implementation
#if canImport(Security)
import Security

private func _keychainSave(token: String, forKey key: String) -> Bool {
    guard let data = token.data(using: .utf8) else { return false }

    let query: [CFString: Any] = [
        kSecClass:           kSecClassGenericPassword,
        kSecAttrAccount:     key,
        kSecValueData:       data,
        kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]

    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
}

private func _keychainLoad(key: String) -> String? {
    let query: [CFString: Any] = [
        kSecClass:        kSecClassGenericPassword,
        kSecAttrAccount:  key,
        kSecReturnData:   true,
        kSecMatchLimit:   kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
          let data = result as? Data,
          let token = String(data: data, encoding: .utf8) else {
        return nil
    }
    return token
}

private func _keychainDelete(key: String) -> Bool {
    let query: [CFString: Any] = [
        kSecClass:       kSecClassGenericPassword,
        kSecAttrAccount: key
    ]
    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
}
#endif // canImport(Security)
