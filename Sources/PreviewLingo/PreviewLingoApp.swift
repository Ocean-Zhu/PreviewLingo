import AppKit
import ApplicationServices

@main
enum PreviewLingoApp {
    static func main() {
        if CommandLine.arguments.contains("--check-selection") {
            let monitor = PreviewSelectionMonitor()
            print("accessibility_trusted=\(AXIsProcessTrusted())")
            print("selected_length=\(monitor.selectedText()?.count ?? 0)")
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
