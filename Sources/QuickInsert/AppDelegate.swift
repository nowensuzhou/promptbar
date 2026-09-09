import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ShortcutStore.shared
    private let hotKeyManager = HotKeyManager()
    private var statusItem: NSStatusItem?
    private var paletteController: PaletteWindowController?
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMainMenu()
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        configureStatusItem()
        configurePalette()

        hotKeyManager.onPress = { [weak self] in
            DispatchQueue.main.async {
                self?.togglePalette()
            }
        }
        hotKeyManager.start()
        openSettings()
    }

    func applicationWillTerminate(_: Notification) {
        hotKeyManager.stop()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows,
           paletteController?.window?.isVisible != true,
           settingsController?.window?.isVisible != true {
            openSettings()
        }
        return true
    }

    @objc private func togglePalette() {
        if let paletteController, paletteController.window?.isVisible == true {
            paletteController.closePalette()
            return
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let frontmost = NSWorkspace.shared.frontmostApplication
        let target = frontmost?.processIdentifier == currentPID
            ? PasteService.shared.lastExternalApplication
            : frontmost
        paletteController?.present(targetApplication: target)
    }

    @objc private func openPaletteFromMenu() {
        togglePalette()
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(store: store)
        }
        settingsController?.showWindow()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 18)
        if let button = item.button {
            button.title = "插"
            button.toolTip = "提示语快捷插入和管理【秘籍】（⌘⇧Space）"
            item.autosaveName = "QuickInsertStatusBarItem"
            item.isVisible = true
        } else {
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let openItem = NSMenuItem(
            title: "打开提示语面板",
            action: #selector(openPaletteFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        let accessibilityItem = NSMenuItem(
            title: "辅助功能权限…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出提示语快捷插入和管理【秘籍】",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let applicationItem = NSMenuItem()
        mainMenu.addItem(applicationItem)
        let applicationMenu = NSMenu(title: "提示语快捷插入和管理【秘籍】")
        applicationMenu.addItem(NSMenuItem(
            title: "隐藏提示语快捷插入和管理【秘籍】",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        ))
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(NSMenuItem(
            title: "退出提示语快捷插入和管理【秘籍】",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        applicationItem.submenu = applicationMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑")
        editItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(
            title: "撤销",
            action: Selector(("undo:")),
            keyEquivalent: "z"
        ))
        editMenu.addItem(NSMenuItem(
            title: "重做",
            action: Selector(("redo:")),
            keyEquivalent: "Z"
        ))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(
            title: "剪切",
            action: NSSelectorFromString("cut:"),
            keyEquivalent: "x"
        ))
        editMenu.addItem(NSMenuItem(
            title: "拷贝",
            action: NSSelectorFromString("copy:"),
            keyEquivalent: "c"
        ))
        editMenu.addItem(NSMenuItem(
            title: "粘贴",
            action: NSSelectorFromString("paste:"),
            keyEquivalent: "v"
        ))
        editMenu.addItem(NSMenuItem(
            title: "全选",
            action: NSSelectorFromString("selectAll:"),
            keyEquivalent: "a"
        ))

        NSApp.mainMenu = mainMenu
    }

    private func configurePalette() {
        let controller = PaletteWindowController(store: store)
        controller.paletteViewController.onInsert = { [weak controller] text in
            let target = controller?.targetApplication
            controller?.closePalette()
            PasteService.shared.insert(text, into: target)
        }
        controller.paletteViewController.onRequestSettings = { [weak self, weak controller] in
            controller?.closePalette()
            self?.openSettings()
        }
        paletteController = controller
    }
}
