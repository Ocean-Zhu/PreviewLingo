import AppKit

final class TranslationPanel: NSPanel {
    private let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 530, height: 260))
    private let status = NSTextField(labelWithString: "")
    private let copyButton = NSButton()
    private var translation = ""

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 340), styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        title = "PreviewLingo"
        level = .floating
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 360, height: 220)
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        if !setFrameUsingName("TranslationPanel"), let screen = NSScreen.main {
            setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 580, y: screen.visibleFrame.maxY - 420))
        }
        setFrameAutosaveName("TranslationPanel")
        let content = contentView!
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 530, height: CGFloat.greatestFiniteMagnitude)
        textView.font = .systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        scroll.documentView = textView
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制译文")
        copyButton.bezelStyle = .texturedRounded
        copyButton.toolTip = "复制译文"
        copyButton.target = self
        copyButton.action = #selector(copyTranslation)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        for view in [scroll, status, copyButton] { content.addSubview(view) }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.bottomAnchor.constraint(equalTo: copyButton.topAnchor, constant: -10),
            copyButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            copyButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            copyButton.widthAnchor.constraint(equalToConstant: 34),
            copyButton.heightAnchor.constraint(equalToConstant: 28),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            status.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            status.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor, constant: -12)
        ])
    }

    func show(_ text: String, copied: Bool, activate: Bool = false) {
        translation = text
        textView.string = text
        status.stringValue = copied ? "译文已复制" : "翻译完成"
        title = "PreviewLingo"
        copyButton.isEnabled = true
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        } else { orderFrontRegardless() }
    }

    func showError(_ message: String) {
        translation = ""
        textView.string = message
        status.stringValue = "翻译失败"
        title = "PreviewLingo"
        copyButton.isEnabled = false
        orderFrontRegardless()
    }

    func showProgress() {
        translation = ""
        textView.string = ""
        status.stringValue = "正在翻译…"
        copyButton.isEnabled = false
        orderFrontRegardless()
    }

    @objc private func copyTranslation() {
        guard !translation.isEmpty else { return }
        Self.copy(translation)
        status.stringValue = "译文已复制"
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
