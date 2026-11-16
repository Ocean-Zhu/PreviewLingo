import AppKit
import ServiceManagement
import PreviewLingoCore

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let store: ConfigurationStore
    private let client: TranslationClient
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?
    private let provider = NSPopUpButton()
    private let apiMode = NSPopUpButton()
    private let address = NSTextField()
    private let model = NSTextField()
    private let key = NSSecureTextField()
    private let language = NSComboBox()
    private let keyRequired = NSButton(checkboxWithTitle: "此接口需要 API Key", target: nil, action: nil)
    private let shortcut = NSButton(checkboxWithTitle: "双空格翻译", target: nil, action: nil)
    private let copyResult = NSButton(checkboxWithTitle: "自动复制译文", target: nil, action: nil)
    private let dock = NSButton(checkboxWithTitle: "在 Dock 中显示", target: nil, action: nil)
    private let login = NSButton(checkboxWithTitle: "登录时启动", target: nil, action: nil)
    private let keyStatus = NSTextField(labelWithString: "")
    private let status = NSTextField(wrappingLabelWithString: "")
    private let testButton = NSButton(title: "测试连接", target: nil, action: nil)
    private var testTask: URLSessionDataTask?

    init(store: ConfigurationStore, client: TranslationClient) {
        self.store = store
        self.client = client
        super.init(window: nil)
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 680), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "PreviewLingo"
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        window = panel
        buildContent(panel.contentView!)
        loadConfiguration()
        panel.initialFirstResponder = key
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildContent(_ content: NSView) {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let title = NSTextField(labelWithString: "PreviewLingo")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        let version = NSTextField(labelWithString: "macOS · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
        version.textColor = .secondaryLabelColor
        let names = NSStackView(views: [title, version])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 4
        let header = NSStackView(views: [icon, names])
        header.spacing = 14

        provider.addItems(withTitles: ProviderPreset.all.map(\.name))
        provider.target = self
        provider.action = #selector(providerChanged)
        apiMode.addItems(withTitles: TranslationAPI.allCases.map(\.title))
        address.placeholderString = "https://api.example.com/v1"
        model.placeholderString = "模型 ID / Model ID"
        key.placeholderString = "API Key"
        language.addItems(withObjectValues: ["Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish", "Portuguese", "Russian", "Arabic"])
        language.isEditable = true
        keyStatus.font = .systemFont(ofSize: 11)
        keyStatus.textColor = .secondaryLabelColor

        let grid = NSGridView(views: [
            [label("服务 / Provider"), provider],
            [label("接口格式 / API"), apiMode],
            [label("API 地址"), address],
            [label("模型 / Model"), model],
            [label("API Key"), key],
            [NSGridCell.emptyContentView, keyStatus],
            [NSGridCell.emptyContentView, keyRequired],
            [label("目标语言"), language]
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        grid.column(at: 0).width = 125
        keyStatus.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for field in [address, model, key] { field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) }

        let options = NSStackView(views: [shortcut, copyResult, dock])
        options.spacing = 18
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.target = self
        login.action = #selector(loginChanged)
        let permission = NSButton(title: "辅助功能权限…", target: self, action: #selector(openPermissions))
        let systemOptions = NSStackView(views: [login, permission])
        systemOptions.spacing = 18
        testButton.target = self
        testButton.action = #selector(testConnection)
        let save = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        save.keyEquivalent = "\r"
        save.bezelStyle = .rounded
        testButton.bezelStyle = .rounded
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [spacer, testButton, save])
        buttons.spacing = 12
        status.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 12)
        let stack = NSStackView(views: [header, grid, options, systemOptions, status, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
            grid.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])
    }

    private func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }

    private func loadConfiguration() {
        let configuration = store.configuration
        provider.selectItem(at: ProviderPreset.all.firstIndex { $0.id == configuration.presetID } ?? ProviderPreset.all.count - 1)
        address.stringValue = configuration.baseURL
        model.stringValue = configuration.model
        apiMode.selectItem(at: TranslationAPI.allCases.firstIndex(of: configuration.api) ?? 0)
        language.stringValue = configuration.targetLanguage
        keyRequired.state = configuration.requiresKey ? .on : .off
        shortcut.state = store.doubleSpaceEnabled ? .on : .off
        copyResult.state = store.copyTranslation ? .on : .off
        dock.state = store.showDockIcon ? .on : .off
        keyStatus.stringValue = store.keys.hasKey(for: configuration) ? "已存入钥匙串；留空保留此接口的密钥" : "密钥仅存储在本机钥匙串"
    }

    @objc private func providerChanged() {
        testTask?.cancel()
        testButton.isEnabled = true
        let preset = ProviderPreset.all[provider.indexOfSelectedItem]
        address.stringValue = preset.baseURL
        model.stringValue = preset.model
        apiMode.selectItem(at: TranslationAPI.allCases.firstIndex(of: preset.api)!)
        keyRequired.state = preset.requiresKey ? .on : .off
        key.stringValue = ""
        keyStatus.stringValue = "留空仅复用此接口已保存的密钥"
        status.stringValue = ""
    }

    private func draft() throws -> TranslationConfiguration {
        let configuration = TranslationConfiguration(presetID: ProviderPreset.all[provider.indexOfSelectedItem].id, baseURL: address.stringValue, model: model.stringValue, api: TranslationAPI.allCases[apiMode.indexOfSelectedItem], targetLanguage: language.stringValue, requiresKey: keyRequired.state == .on)
        try configuration.validate()
        return configuration
    }

    @objc private func saveSettings() {
        do {
            let configuration = try draft()
            let entered = key.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !entered.isEmpty { try store.keys.save(entered, for: configuration) }
            if configuration.requiresKey && !store.keys.hasKey(for: configuration) { throw ConfigurationError.missingKey }
            try store.save(configuration)
            store.doubleSpaceEnabled = shortcut.state == .on
            store.copyTranslation = copyResult.state == .on
            store.showDockIcon = dock.state == .on
            key.stringValue = ""
            keyStatus.stringValue = configuration.requiresKey ? "已存入钥匙串；留空保留此接口的密钥" : "此接口无需密钥"
            status.stringValue = "设置已保存。"
            onSave?()
        } catch { status.stringValue = error.localizedDescription }
    }

    @objc private func testConnection() {
        do {
            let configuration = try draft()
            let entered = key.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let token = entered.isEmpty ? try store.keys.key(for: configuration) : entered
            testButton.isEnabled = false
            status.stringValue = "正在测试连接…"
            testTask = client.translate(text: "Hello, world.", configuration: configuration, key: token) { [weak self] result in
                guard let self = self else { return }
                self.testButton.isEnabled = true
                switch result {
                case .success(let text): self.status.stringValue = "连接成功：\(text.prefix(160))"
                case .failure(let error): self.status.stringValue = error.localizedDescription
                }
            }
        } catch { status.stringValue = error.localizedDescription }
    }

    @objc private func openPermissions() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func loginChanged() {
        do {
            if login.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            status.stringValue = SMAppService.mainApp.status == .requiresApproval ? "请在系统设置的登录项中允许 PreviewLingo。" : "登录项已更新。"
        } catch {
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            status.stringValue = error.localizedDescription
        }
    }

    func windowWillClose(_ notification: Notification) { onClose?() }
}
