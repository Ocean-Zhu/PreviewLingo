import Foundation
import Security
import PreviewLingoCore

final class KeychainStore {
    private let service = "io.github.ocean-zhu.PreviewLingo"
    private let legacyService = "com.zhuhai.QwenPreviewTranslator"
    private let legacyAccount = "dashscope-api-key"

    private func query(service: String, account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    private func hasItem(service: String, account: String) -> Bool {
        var request = query(service: service, account: account)
        request[kSecReturnAttributes as String] = true
        var item: CFTypeRef?
        return SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess
    }

    var hasLegacyKey: Bool { hasItem(service: legacyService, account: legacyAccount) }

    func hasKey(for configuration: TranslationConfiguration) -> Bool {
        hasItem(service: service, account: configuration.credentialAccount) || (configuration.canUseLegacyKey && hasLegacyKey)
    }

    func key(for configuration: TranslationConfiguration) throws -> String? {
        var request = query(service: service, account: configuration.credentialAccount)
        if !hasItem(service: service, account: configuration.credentialAccount), configuration.canUseLegacyKey {
            request = query(service: legacyService, account: legacyAccount)
        }
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw TranslationFailure("无法读取钥匙串中的 API Key，请在系统授权窗口允许 PreviewLingo 访问。")
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String, for configuration: TranslationConfiguration) throws {
        let request = query(service: service, account: configuration.credentialAccount)
        let data = Data(value.utf8)
        var status = SecItemUpdate(request as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addition = request
            addition[kSecValueData as String] = data
            status = SecItemAdd(addition as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw TranslationFailure("无法保存 API Key 到钥匙串（\(status)）。原有密钥未被删除。")
        }
    }
}
