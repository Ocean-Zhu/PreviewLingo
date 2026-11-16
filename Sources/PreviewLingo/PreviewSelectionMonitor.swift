import AppKit
import ApplicationServices
import PreviewLingoCore

final class PreviewSelectionMonitor {
    var onSelection: ((String) -> Void)?
    var onStatusChanged: (() -> Void)?
    var isEnabled = true
    private var timer: Timer?
    private var trusted: Bool?
    private var reportedListening: Bool?
    private var applicationPID: pid_t?
    private var window: AXUIElement?
    private var documentIdentity = ""
    private var textElement: AXUIElement?
    private var cachedContext: String?
    private var shortcut = DoubleSpaceShortcut()
    private var keyboardTap: CFMachPort?
    private var keyboardSource: CFRunLoopSource?
    private var lastTapAttempt: TimeInterval = 0

    var isListeningForShortcut: Bool {
        guard isEnabled, let tap = keyboardTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    func start() {
        guard timer == nil else { return }
        let poller = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(poller, forMode: .common)
        timer = poller
    }

    func reset() {
        cachedContext = nil
        shortcut.cancelSequence()
        textElement = nil
    }

    func selectedText(requireFrontmost: Bool = true) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let app: NSRunningApplication?
        if requireFrontmost {
            let frontmost = NSWorkspace.shared.frontmostApplication
            app = frontmost?.bundleIdentifier == "com.apple.Preview" ? frontmost : nil
        } else {
            app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Preview").first
        }
        guard let app = app else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.2)
        guard let currentWindow = elementAttribute(appElement, kAXFocusedWindowAttribute) else {
            return nil
        }
        let document = attribute(currentWindow, kAXDocumentAttribute) as? String
            ?? attribute(currentWindow, kAXTitleAttribute) as? String ?? ""
        if applicationPID != app.processIdentifier || window == nil || !CFEqual(window, currentWindow) || documentIdentity != document {
            applicationPID = app.processIdentifier
            window = currentWindow
            documentIdentity = document
            textElement = nil
            cachedContext = nil
            shortcut.cancelSequence()
        }
        if let cached = textElement,
           let text = attribute(cached, kAXSelectedTextAttribute) as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Preview exposes the whole PDF selection on its content group.
        var queue: [(AXUIElement, Int)] = [(currentWindow, 0)]
        var index = 0
        while index < queue.count && index < 120 {
            let (element, depth) = queue[index]
            index += 1
            let role = attribute(element, kAXRoleAttribute) as? String ?? ""
            if role == kAXToolbarRole || role.hasPrefix("AXMenu") { continue }
            if ["AXGroup", "AXPage", "AXPDFDocument"].contains(role),
               let text = attribute(element, kAXSelectedTextAttribute) as? String {
                textElement = element
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if depth < 8 {
                for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                    queue.append((child, depth + 1))
                }
            }
        }
        return nil
    }

    private func poll() {
        let hasTrust = AXIsProcessTrusted()
        if isEnabled && hasTrust { installKeyboardTapIfNeeded() }
        let listening = isListeningForShortcut
        if trusted != hasTrust || reportedListening != listening {
            trusted = hasTrust
            reportedListening = listening
            onStatusChanged?()
        }
        guard isEnabled, hasTrust, isDocumentFocused(),
              NSEvent.pressedMouseButtons & 1 == 0,
              let text = selectedText(), !text.isEmpty else {
            cachedContext = nil
            shortcut.cancelSequence()
            return
        }
        let context = contextIdentifier(for: text)
        if cachedContext != context {
            cachedContext = context
            shortcut.cancelSequence()
        }
    }

    private func installKeyboardTapIfNeeded() {
        guard keyboardTap == nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTapAttempt >= 1 else { return }
        lastTapAttempt = now
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info = info else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<PreviewSelectionMonitor>.fromOpaque(info).takeUnretainedValue()
            return monitor.handleKeyboardEvent(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
        keyboardTap = tap
        keyboardSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleKeyboardEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            shortcut = DoubleSpaceShortcut()
            if let tap = keyboardTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .flagsChanged {
            shortcut.cancelSequence()
            return Unmanaged.passUnretained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn]
        let hasModifiers = !event.flags.intersection(modifiers).isEmpty
        var context: String?
        if keyCode == 49 && type == .keyDown && isEnabled && !hasModifiers && cachedContext != nil && isDocumentFocused() {
            context = cachedContext
        }
        let decision = shortcut.handle(
            keyCode: keyCode,
            isDown: type == .keyDown,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            hasModifiers: hasModifiers,
            context: context,
            timestamp: Double(event.timestamp) / 1_000_000_000
        )
        if decision == .trigger, let expectedContext = context {
            // Read the selection outside the event tap so keyboard delivery stays responsive.
            DispatchQueue.main.async {
                guard self.isEnabled, let text = self.selectedText(), !text.isEmpty,
                      self.contextIdentifier(for: text) == expectedContext else { return }
                self.onSelection?(text)
            }
        }
        return decision == .passThrough ? Unmanaged.passUnretained(event) : nil
    }

    private func contextIdentifier(for text: String) -> String {
        return "\(applicationPID ?? 0):\(window.map { CFHash($0) } ?? 0):\(documentIdentity):\(text.hashValue)"
    }

    private func isDocumentFocused() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == "com.apple.Preview" else { return false }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.05)
        guard let focused = elementAttribute(element, kAXFocusedUIElementAttribute),
              let role = attribute(focused, kAXRoleAttribute) as? String else { return false }
        return ["AXScrollArea", "AXGroup", "AXPage", "AXPDFDocument", "AXStaticText", "AXSplitGroup", "AXUnknown"].contains(role)
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }
}
