import ApplicationServices
import AppKit

final class PasteService {
    static let shared = PasteService()

    private(set) var lastExternalApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    private init() {
        captureFrontmostApplication()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  application.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else { return }

            self.lastExternalApplication = application
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    private func resolvedTargetApplication(_ requestedApplication: NSRunningApplication?) -> NSRunningApplication? {
        if let requestedApplication,
           requestedApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            return requestedApplication
        }
        return lastExternalApplication
    }

    private func captureFrontmostApplication() {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        guard frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        lastExternalApplication = frontmostApplication
    }

    func insert(_ text: String, into targetApplication: NSRunningApplication?) {
        guard !text.isEmpty else { return }
        let resolvedTargetApplication = resolvedTargetApplication(targetApplication)

        guard AXIsProcessTrusted() else {
            showAccessibilityAlert()
            return
        }

        let snapshot = ClipboardSnapshot()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        resolvedTargetApplication?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Self.postPasteShortcut()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard pasteboard.string(forType: .string) == text else { return }
                snapshot.restore(to: pasteboard)
            }
        }
    }

    private static func postPasteShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "PromptBar 需要控制当前应用来完成粘贴。请在“系统设置 > 隐私与安全性 > 辅助功能”中允许“PromptBar”，然后重试。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct ClipboardSnapshot {
    private let items: [[String: Data]]

    init() {
        items = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var values: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    values[type.rawValue] = data
                }
            }
            return values
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (rawType, data) in values {
                item.setData(data, forType: NSPasteboard.PasteboardType(rawValue: rawType))
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}
