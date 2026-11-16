import Foundation
import PreviewLingoCore

final class ConfigurationStore {
    let keys = KeychainStore()
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: ["doubleSpaceEnabled": true, "copyTranslation": true, "showDockIcon": true])
        if defaults.data(forKey: "translationConfiguration") == nil, keys.hasLegacyKey {
            try? save(.legacyQwen)
        }
    }

    var configuration: TranslationConfiguration {
        guard let data = defaults.data(forKey: "translationConfiguration"),
              let configuration = try? JSONDecoder().decode(TranslationConfiguration.self, from: data) else { return .standard }
        return configuration
    }

    func save(_ configuration: TranslationConfiguration) throws {
        try configuration.validate()
        defaults.set(try JSONEncoder().encode(configuration), forKey: "translationConfiguration")
    }

    var doubleSpaceEnabled: Bool {
        get { defaults.bool(forKey: "doubleSpaceEnabled") }
        set { defaults.set(newValue, forKey: "doubleSpaceEnabled") }
    }
    var copyTranslation: Bool {
        get { defaults.bool(forKey: "copyTranslation") }
        set { defaults.set(newValue, forKey: "copyTranslation") }
    }
    var showDockIcon: Bool {
        get { defaults.bool(forKey: "showDockIcon") }
        set { defaults.set(newValue, forKey: "showDockIcon") }
    }
}
