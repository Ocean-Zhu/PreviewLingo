import Foundation
import PreviewLingoCore

var checks = 0
func expect(_ value: Bool, _ description: String) throws {
    guard value else { throw TranslationFailure("Check failed: \(description)") }
    checks += 1
}
func expectFailure(_ description: String, _ body: () throws -> Void) throws {
    do { try body() } catch { checks += 1; return }
    throw TranslationFailure("Expected failure: \(description)")
}
for preset in ProviderPreset.all where preset.id != "custom" {
    try TranslationConfiguration(preset: preset).validate()
    checks += 1
}
for base in ["https://example.com", "https://example.com/v1/", "https://example.com/v1/chat/completions"] {
    var config = TranslationConfiguration.standard
    config.baseURL = base
    try expect(try config.endpoint().absoluteString == "https://example.com/v1/chat/completions", "Endpoint normalization")
}
for base in ["http://example.com/v1", "https://user:password@example.com", "not a URL", "https://example.com/v1?api_key=test"] {
    var config = TranslationConfiguration.standard
    config.baseURL = base
    try expectFailure("Invalid URL") { try config.validate() }
}
for host in ["localhost", "127.0.0.1", "[::1]"] {
    var config = TranslationConfiguration.standard
    config.baseURL = "http://\(host):11434/v1"
    try config.validate()
    checks += 1
}
for api in TranslationAPI.allCases {
    var config = TranslationConfiguration.standard
    config.api = api
    let request = try TranslationRequest.make(text: "Hello", configuration: config, key: "opaque-test-token")
    let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    try expect(body["api_key"] == nil, "No key in body")
    try expect((body["messages"] as! [[String: Any]]).count == (api == .chatCompletions ? 2 : 1), "Message shape")
    if api == .qwenMT { try expect(body["translation_options"] != nil, "Qwen translation options") }
    if api == .anthropicMessages {
        try expect(request.value(forHTTPHeaderField: "x-api-key") == "opaque-test-token", "Anthropic key header")
        try expect(body["system"] != nil && body["max_tokens"] != nil, "Anthropic required fields")
    } else { try expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer opaque-test-token", "Bearer header") }
}
let local = TranslationConfiguration(preset: ProviderPreset.all.first { $0.id == "ollama" }!)
try expect(try TranslationRequest.make(text: "Hello", configuration: local, key: nil).value(forHTTPHeaderField: "Authorization") == nil, "Local service without key")
try expectFailure("Missing cloud key") { _ = try TranslationRequest.make(text: "Hello", configuration: .standard, key: nil) }
let response = Data(#"{"choices":[{"message":{"content":"你好"}}]}"#.utf8)
try expect(try TranslationRequest.parse(data: response, statusCode: 200, api: .chatCompletions) == "你好", "Chat response")
let anthropic = Data(#"{"content":[{"type":"text","text":"你好"}]}"#.utf8)
try expect(try TranslationRequest.parse(data: anthropic, statusCode: 200, api: .anthropicMessages) == "你好", "Anthropic response")
try expectFailure("HTTP failure") { _ = try TranslationRequest.parse(data: response, statusCode: 401, api: .chatCompletions) }
try expectFailure("Empty response") { _ = try TranslationRequest.parse(data: Data(), statusCode: 200, api: .chatCompletions) }
try expect(TranslationRequest.normalizePDFText("A pipe-\nline.\nNext.\n \nNew paragraph.") == "A pipeline. Next.\n\nNew paragraph.", "PDF paragraphs")
var remote = TranslationConfiguration.legacyQwen
let oldAccount = remote.credentialAccount
remote.baseURL = "https://other.example/v1"
try expect(remote.credentialAccount != oldAccount && !remote.canUseLegacyKey, "Credential isolation")
var keys = DoubleSpaceShortcut()
try expect(keys.handle(keyCode: 49, isDown: true, context: nil, timestamp: 1) == .passThrough, "Space outside a selection")
_ = keys.handle(keyCode: 49, isDown: false, context: nil, timestamp: 1.1)
try expect(keys.handle(keyCode: 49, isDown: true, context: "pdf", timestamp: 2) == .consume, "First selected Space")
try expect(keys.handle(keyCode: 49, isDown: true, isRepeat: true, context: "pdf", timestamp: 2.1) == .consume, "Repeat does not translate")
_ = keys.handle(keyCode: 49, isDown: false, context: nil, timestamp: 2.15)
try expect(keys.handle(keyCode: 49, isDown: true, context: "pdf", timestamp: 2.2) == .trigger, "Physical double Space")
_ = keys.handle(keyCode: 49, isDown: false, context: nil, timestamp: 2.3)
try expect(keys.handle(keyCode: 8, isDown: true, hasModifiers: true, context: nil, timestamp: 3) == .passThrough, "Command+C unchanged")
print("Passed \(checks) dependency-free core checks")
