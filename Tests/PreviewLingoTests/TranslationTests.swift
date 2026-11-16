import XCTest
@testable import PreviewLingoCore

final class TranslationTests: XCTestCase {
    func testEndpoints() throws {
        for base in ["https://example.com", "https://example.com/v1/", "https://example.com/v1/chat/completions"] {
            var config = TranslationConfiguration.standard
            config.baseURL = base
            XCTAssertEqual(try config.endpoint().absoluteString, "https://example.com/v1/chat/completions")
        }
        XCTAssertEqual(try TranslationConfiguration.legacyQwen.endpoint().path, "/compatible-mode/v1/chat/completions")
        var config = TranslationConfiguration.standard
        config.baseURL = "https://example.com/compatible-mode"
        XCTAssertEqual(try config.endpoint().path, "/compatible-mode/v1/chat/completions")
        config.api = .anthropicMessages
        config.baseURL = "https://api.anthropic.com/v1"
        XCTAssertEqual(try config.endpoint().path, "/v1/messages")
    }

    func testURLValidationAndLocalModels() throws {
        var config = TranslationConfiguration.standard
        for base in ["http://example.com/v1", "https://user:password@example.com/v1", "not a URL", "https://example.com/v1?api_key=test", "https://example.com/#key"] {
            config.baseURL = base
            XCTAssertThrowsError(try config.validate(), base)
        }
        for base in ["http://localhost:11434/v1", "http://127.0.0.1:11434/v1", "http://[::1]:11434/v1"] {
            config.baseURL = base
            XCTAssertNoThrow(try config.validate())
        }
        config.baseURL = "https://example.com/v1?api-version=2026-01-01"
        XCTAssertEqual(try config.endpoint().query, "api-version=2026-01-01")
    }

    func testProviderPresets() throws {
        for preset in ProviderPreset.all where preset.id != "custom" {
            XCTAssertNoThrow(try TranslationConfiguration(preset: preset).validate(), preset.id)
        }
    }

    func testOpenAIFormatAndOpaqueKey() throws {
        let request = try TranslationRequest.make(text: "Hello", configuration: .standard, key: "opaque-test-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer opaque-test-token")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual((body["messages"] as? [[String: String]])?.count, 2)
        XCTAssertNil(body["translation_options"])
        XCTAssertNil(body["api_key"])
    }

    func testQwenHasExactlyOneUserMessage() throws {
        let request = try TranslationRequest.make(text: "Hello", configuration: .legacyQwen, key: "opaque-test-token")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertEqual((body["messages"] as? [[String: String]])?.count, 1)
        XCTAssertEqual((body["translation_options"] as? [String: String])?["target_lang"], "Chinese")
    }

    func testAnthropicFormat() throws {
        let config = TranslationConfiguration(preset: ProviderPreset.all.first { $0.id == "anthropic" }!)
        let request = try TranslationRequest.make(text: "Hello", configuration: config, key: "opaque-test-token")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "opaque-test-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertNotNil(body["max_tokens"])
        XCTAssertNotNil(body["system"])
    }

    func testLocalEndpointWithoutKey() throws {
        let config = TranslationConfiguration(preset: ProviderPreset.all.first { $0.id == "ollama" }!)
        let request = try TranslationRequest.make(text: "Hello", configuration: config, key: nil)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertThrowsError(try TranslationRequest.make(text: "Hello", configuration: .standard, key: nil))
    }

    func testCredentialIsolationAndMigration() {
        var config = TranslationConfiguration.legacyQwen
        XCTAssertTrue(config.canUseLegacyKey)
        let first = config.credentialAccount
        config.baseURL = "https://different.example/v1"
        XCTAssertNotEqual(config.credentialAccount, first)
        XCTAssertFalse(config.canUseLegacyKey)
        config = .legacyQwen
        config.api = .chatCompletions
        XCTAssertFalse(config.canUseLegacyKey)
        XCTAssertNotEqual(config.credentialAccount, first)
    }

    func testResponseFormatsAndFailures() throws {
        let chat = Data(#"{"choices":[{"message":{"content":"你好"}}]}"#.utf8)
        XCTAssertEqual(try TranslationRequest.parse(data: chat, statusCode: 200, api: .chatCompletions), "你好")
        let blocks = Data(#"{"choices":[{"message":{"content":[{"type":"text","text":"你好"}]}}]}"#.utf8)
        XCTAssertEqual(try TranslationRequest.parse(data: blocks, statusCode: 200, api: .chatCompletions), "你好")
        let anthropic = Data(#"{"content":[{"type":"text","text":"你好"}],"stop_reason":"end_turn"}"#.utf8)
        XCTAssertEqual(try TranslationRequest.parse(data: anthropic, statusCode: 200, api: .anthropicMessages), "你好")
        XCTAssertThrowsError(try TranslationRequest.parse(data: Data(), statusCode: 200, api: .chatCompletions))
        XCTAssertThrowsError(try TranslationRequest.parse(data: chat, statusCode: 401, api: .chatCompletions))
        let truncated = Data(#"{"choices":[{"message":{"content":"partial"},"finish_reason":"length"}]}"#.utf8)
        XCTAssertThrowsError(try TranslationRequest.parse(data: truncated, statusCode: 200, api: .chatCompletions))
    }

    func testPDFSoftLinesAndParagraphs() {
        XCTAssertEqual(TranslationRequest.normalizePDFText("A pipe-\nline.\nNext line.\n \nNew paragraph."), "A pipeline. Next line.\n\nNew paragraph.")
    }
}
