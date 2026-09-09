import AppKit

final class PaletteWindowController: NSWindowController {
    let paletteViewController: PaletteViewController
    private var keyMonitor: Any?
    private(set) var targetApplication: NSRunningApplication?

    init(store: ShortcutStore) {
        paletteViewController = PaletteViewController(store: store)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 470),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        panel.contentViewController = paletteViewController

        super.init(window: panel)

        paletteViewController.onClose = { [weak self] in
            self?.closePalette()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(targetApplication: NSRunningApplication?) {
        self.targetApplication = targetApplication
        paletteViewController.refresh()

        guard let panel = window as? NSPanel else { return }
        position(panel)

        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
        panel.makeKeyAndOrderFront(nil)
        paletteViewController.focusSearch()
    }

    func closePalette() {
        removeKeyMonitor()
        window?.orderOut(nil)
        targetApplication = nil
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isVisible == true else { return event }
            return self.paletteViewController.handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func position(_ panel: NSPanel) {
        let size = panel.frame.size
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        var origin = NSPoint(
            x: mouseLocation.x - size.width / 2,
            y: mouseLocation.y - size.height - 14
        )

        if origin.x < visibleFrame.minX + 12 {
            origin.x = visibleFrame.minX + 12
        }
        if origin.x + size.width > visibleFrame.maxX - 12 {
            origin.x = visibleFrame.maxX - size.width - 12
        }
        if origin.y < visibleFrame.minY + 12 {
            origin.y = mouseLocation.y + 24
        }
        if origin.y + size.height > visibleFrame.maxY - 12 {
            origin.y = visibleFrame.maxY - size.height - 12
        }

        panel.setFrameOrigin(origin)
    }
}
