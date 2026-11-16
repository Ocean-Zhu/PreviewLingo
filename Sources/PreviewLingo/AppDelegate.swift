import AppKit
import ApplicationServices
import PreviewLingoCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ConfigurationStore()
    private let client = TranslationClient()
    private let monitor = PreviewSelectionMonitor()
    private var statusItem: NSStatusItem?
    private var shortcutItem: NSMenuItem?
    private var settings: SettingsWindowController?
    private var panel: TranslationPanel?
    private var activeTask: URLSessionDataTask?
    private var generation = 0
    private var requestCount = 0
    private var state = "idle"
    private var resultLength = 0
    private var lastSelectionLength = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        buildStatusMenu()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        monitor.isEnabled = store.doubleSpaceEnabled
        monitor.onSelection = { [weak self] text in self?.translate(text, selection: true) }
        monitor.onStatusChanged = { [weak self] in self?.recordStatus() }
        monitor.start()
        applySettings()
        recordStatus()
        if CommandLine.arguments.contains("--migrate-login") { try? SMAppService.mainApp.register() }
        let launchReason = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        let loginLaunch = launchReason == keyAELaunchedAsLogInItem
        if !CommandLine.arguments.contains("--background") && !loginLaunch { openSettings() }
        if store.doubleSpaceEnabled && !AXIsProcessTrusted() {
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func buildMainMenu() {
        let main = NSMenu()
        let app = NSMenu(title: "PreviewLingo")
        app.addItem(item("设置…", #selector(openSettings), key: ","))
        app.addItem(.separator())
        app.addItem(NSMenuItem(title: "退出 PreviewLingo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = app
        main.addItem(appItem)
        let edit = NSMenu(title: "编辑")
        for (title, action, key) in [
            ("剪切", #selector(NSText.cut(_:)), "x"), ("拷贝", #selector(NSText.copy(_:)), "c"),
            ("粘贴", #selector(NSText.paste(_:)), "v"), ("全选", #selector(NSText.selectAll(_:)), "a")
        ] { edit.addItem(NSMenuItem(title: title, action: action, keyEquivalent: key)) }
        let editItem = NSMenuItem()
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func buildStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "PreviewLingo")
        item.button?.toolTip = "PreviewLingo"
        let menu = NSMenu()
        let name = NSMenuItem(title: "PreviewLingo", action: nil, keyEquivalent: "")
        name.isEnabled = false
        menu.addItem(name)
        let shortcut = self.item("Preview 双击空格翻译", #selector(toggleShortcut))
        shortcut.state = store.doubleSpaceEnabled ? .on : .off
        shortcutItem = shortcut
        menu.addItem(shortcut)
        menu.addItem(self.item("翻译剪贴板文字", #selector(translateClipboard)))
        menu.addItem(.separator())
        menu.addItem(self.item("设置…", #selector(openSettings)))
        menu.addItem(self.item("辅助功能权限…", #selector(openPermissions)))
        menu.addItem(self.item("在访达中显示 App", #selector(revealApp)))
        menu.addItem(self.item("GitHub", #selector(openRepository)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 PreviewLingo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        item.menu = menu
        statusItem = item
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openSettings() {
        if settings == nil {
            let controller = SettingsWindowController(store: store, client: client)
            controller.onSave = { [weak self] in self?.applySettings() }
            controller.onClose = { [weak self] in self?.applyActivationPolicy() }
            settings = controller
        }
        NSApp.setActivationPolicy(.regular)
        settings?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settings?.window?.makeKeyAndOrderFront(nil)
    }

    private func applySettings() {
        monitor.isEnabled = store.doubleSpaceEnabled
        monitor.reset()
        shortcutItem?.state = store.doubleSpaceEnabled ? .on : .off
        generation += 1
        activeTask?.cancel()
        applyActivationPolicy()
        recordStatus()
    }

    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(store.showDockIcon || settings?.window?.isVisible == true ? .regular : .accessory)
    }

    @objc private func toggleShortcut() {
        store.doubleSpaceEnabled.toggle()
        applySettings()
    }

    @objc private func translateClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("剪贴板中没有文字。")
            return
        }
        translate(text, selection: false)
    }

    @objc(translateSelection:userData:error:)
    func translateSelection(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "没有读取到所选文字。" as NSString
            return
        }
        DispatchQueue.main.async { self.translate(text, selection: false) }
    }

    private func translate(_ raw: String, selection: Bool) {
        let text = TranslationRequest.normalizePDFText(raw)
        guard !text.isEmpty else { return }
        let configuration = store.configuration
        if configuration.requiresKey && !store.keys.hasKey(for: configuration) {
            openSettings()
            return
        }
        generation += 1
        let identifier = generation
        activeTask?.cancel()
        lastSelectionLength = text.count
        state = "translating"
        if panel == nil { panel = TranslationPanel() }
        panel?.showProgress()
        recordStatus()
        do {
            let key = try store.keys.key(for: configuration)
            requestCount += 1
            recordStatus()
            activeTask = client.translate(text: text, configuration: configuration, key: key) { [weak self] result in
                guard let self = self, self.generation == identifier else { return }
                self.activeTask = nil
                if selection && self.monitor.selectedText(requireFrontmost: false) != raw.trimmingCharacters(in: .whitespacesAndNewlines) {
                    self.state = "discarded_stale_result"
                    self.panel?.orderOut(nil)
                    self.recordStatus()
                    return
                }
                switch result {
                case .success(let translated):
                    self.state = "success"
                    self.resultLength = translated.count
                    if self.store.copyTranslation { TranslationPanel.copy(translated) }
                    self.panel?.show(translated, copied: self.store.copyTranslation)
                case .failure(let error):
                    self.state = "error"
                    self.panel?.showError(error.localizedDescription)
                }
                self.recordStatus()
            }
        } catch {
            state = "error"
            panel?.showError(error.localizedDescription)
            recordStatus()
        }
    }

    private func showError(_ message: String) {
        if panel == nil { panel = TranslationPanel() }
        panel?.showError(message)
    }

    @objc private func openPermissions() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    @objc private func openRepository() { NSWorkspace.shared.open(URL(string: "https://github.com/Ocean-Zhu/PreviewLingo")!) }

    private func recordStatus() {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/PreviewLingo")
        let values: [String: Any] = [
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "pid": ProcessInfo.processInfo.processIdentifier, "trigger_mode": "double_space",
            "shortcut_enabled": store.doubleSpaceEnabled, "event_tap_active": monitor.isListeningForShortcut,
            "accessibility_trusted": AXIsProcessTrusted(), "api_key_configured": store.keys.hasKey(for: store.configuration),
            "request_count": requestCount, "state": state, "result_length": resultLength,
            "last_selection_length": lastSelectionLength, "result_visible": panel?.isVisible ?? false
        ]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: folder.appendingPathComponent("status.json"), options: .atomic)
        }
    }
}
