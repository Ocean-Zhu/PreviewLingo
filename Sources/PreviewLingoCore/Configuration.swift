import Foundation

public enum TranslationAPI: String, Codable, CaseIterable {
    case chatCompletions, anthropicMessages, qwenMT
    public var title: String {
        switch self {
        case .chatCompletions: return "OpenAI-compatible Chat Completions"
        case .anthropicMessages: return "Anthropic Messages"
        case .qwenMT: return "Qwen-MT Translation"
        }
    }
}

public struct ProviderPreset {
    public let id: String
    public let name: String
    public let baseURL: String
    public let model: String
    public let api: TranslationAPI
    public let requiresKey: Bool

    public static let all: [ProviderPreset] = [
        .init(id: "openai", name: "OpenAI", baseURL: "https://api.openai.com/v1", model: "gpt-4.1-mini", api: .chatCompletions, requiresKey: true),
        .init(id: "anthropic", name: "Anthropic", baseURL: "https://api.anthropic.com/v1", model: "claude-haiku-5-5", api: .anthropicMessages, requiresKey: true),
        .init(id: "deepseek", name: "DeepSeek", baseURL: "https://api.deepseek.com/v1", model: "deepseek-flash", api: .chatCompletions, requiresKey: true),
        .init(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1", model: "openai/gpt-4.1-mini", api: .chatCompletions, requiresKey: true),
        .init(id: "gemini", name: "Google Gemini", baseURL: "https://generativelanguage.googleapis.com/v1beta/openai", model: "gemini-4-hydrogen", api: .chatCompletions, requiresKey: true),
        .init(id: "qwen-cn", name: "Qwen-MT · China", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-mt-plus", api: .qwenMT, requiresKey: true),
        .init(id: "qwen-global", name: "Qwen-MT · International", baseURL: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1", model: "qwen-mt-plus", api: .qwenMT, requiresKey: true),
        .init(id: "ollama", name: "Ollama · Local", baseURL: "http://localhost:11434/v1", model: "qwen3:8b", api: .chatCompletions, requiresKey: false),
        .init(id: "custom", name: "Custom / 自定义", baseURL: "", model: "", api: .chatCompletions, requiresKey: true)
    ]
}

public enum ConfigurationError: LocalizedError {
    case invalidURL, insecureURL, missingModel, missingLanguage, missingKey
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "请输入有效的 API 地址，不能包含用户名、密码或 URL 片段。"
        case .insecureURL: return "远程 API 必须使用 HTTPS。本机 localhost 接口可使用 HTTP。"
        case .missingModel: return "请输入此服务支持的模型名称。"
        case .missingLanguage: return "请选择目标语言。"
        case .missingKey: return "此接口尚未配置 API Key，请打开设置。"
        }
    }
}

public struct TranslationConfiguration: Codable, Equatable {
    public var presetID: String
    public var baseURL: String
    public var model: String
    public var api: TranslationAPI
    public var targetLanguage: String
    public var requiresKey: Bool

    public init(presetID: String, baseURL: String, model: String, api: TranslationAPI, targetLanguage: String = "Chinese", requiresKey: Bool = true) {
        self.presetID = presetID
        self.baseURL = baseURL
        self.model = model
        self.api = api
        self.targetLanguage = targetLanguage
        self.requiresKey = requiresKey
    }

    public init(preset: ProviderPreset, targetLanguage: String = "Chinese") {
        self.init(presetID: preset.id, baseURL: preset.baseURL, model: preset.model, api: preset.api, targetLanguage: targetLanguage, requiresKey: preset.requiresKey)
    }

    public static var standard: TranslationConfiguration { .init(preset: ProviderPreset.all[0]) }
    public static var legacyQwen: TranslationConfiguration { .init(preset: ProviderPreset.all.first { $0.id == "qwen-cn" }!) }

    public func endpoint() throws -> URL {
        let input = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: input),
              let scheme = parts.scheme?.lowercased(), let host = parts.host?.lowercased(),
              !host.isEmpty, parts.user == nil, parts.password == nil, parts.fragment == nil,
              ["https", "http"].contains(scheme) else { throw ConfigurationError.invalidURL }
        let local = host == "localhost" || host.hasSuffix(".localhost") || host == "127.0.0.1" || host == "::1" || host == "[::1]"
        guard scheme == "https" || local else { throw ConfigurationError.insecureURL }
        let secretParameters = Set(["key", "api_key", "apikey", "api-key", "token", "access_token", "authorization"])
        guard !(parts.queryItems ?? []).contains(where: { secretParameters.contains($0.name.lowercased()) }) else { throw ConfigurationError.invalidURL }
        parts.scheme = scheme
        parts.host = host
        let suffix = api == .anthropicMessages ? "/messages" : "/chat/completions"
        var path = parts.path
        while path.hasSuffix("/") { path.removeLast() }
        if !path.hasSuffix(suffix) {
            if path.isEmpty || path.hasSuffix("/compatible-mode") { path += "/v1" }
            path += suffix
        }
        parts.path = path
        guard let url = parts.url else { throw ConfigurationError.invalidURL }
        return url
    }

    public func validate() throws {
        _ = try endpoint()
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ConfigurationError.missingModel }
        guard !targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ConfigurationError.missingLanguage }
    }

    public var credentialAccount: String {
        "\(api.rawValue)|\((try? endpoint().absoluteString) ?? baseURL)"
    }

    public var canUseLegacyKey: Bool {
        api == .qwenMT && (try? endpoint()) == (try? Self.legacyQwen.endpoint())
    }
}
