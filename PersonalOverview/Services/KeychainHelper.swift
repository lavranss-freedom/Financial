import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.lavranss.PersonalOverview"
    private static let pinAccount = "app.pin"

    static func savePIN(_ pin: String) -> Bool {
        guard let data = pin.data(using: .utf8) else { return false }
        deletePIN()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pinAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func loadPIN() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pinAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func hasPIN() -> Bool {
        loadPIN() != nil
    }

    @discardableResult
    static func deletePIN() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pinAccount,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    static func verifyPIN(_ pin: String) -> Bool {
        guard let stored = loadPIN() else { return false }
        return stored == pin
    }
}
