import AppKit

final class SettingsWindowController: NSWindowController {
    init(store: ShortcutStore) {
        let viewController = SettingsViewController(store: store)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 570),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PromptBar 设置"
        window.minSize = NSSize(width: 680, height: 440)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = viewController
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
