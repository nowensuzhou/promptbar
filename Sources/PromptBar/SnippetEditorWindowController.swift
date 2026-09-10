import AppKit

final class EditorTextView: NSTextView {
    var onTextChange: ((String) -> Void)?

    override func didChangeText() {
        super.didChangeText()
        onTextChange?(string)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers?.lowercased()
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if key == "v", modifiers == .command || modifiers == .control {
            paste(nil)
            onTextChange?(string)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}

final class SnippetEditorWindowController: NSWindowController {
    private let titleField = NSTextField()
    private let contentView = EditorTextView()
    private let warningLabel = NSTextField(labelWithString: "")
    private let categoryName: String
    private let existingItem: ShortcutItem?
    private var onSave: ((String, String) -> Void)?

    init(
        categoryName: String,
        item: ShortcutItem?,
        onSave: @escaping (String, String) -> Void
    ) {
        self.categoryName = categoryName
        self.existingItem = item
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = item == nil ? "添加快捷短语" : "编辑快捷短语"
        window.isMovableByWindowBackground = false
        window.titlebarAppearsTransparent = false
        window.center()

        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.center()
    }

    private func buildContent() {
        guard let root = window?.contentView else { return }
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let heading = makeTextLabel(
            existingItem == nil ? "添加快捷短语" : "编辑快捷短语",
            size: 20,
            weight: .bold
        )
        let categoryLabel = makeTextLabel(
            "分类：\(categoryName)",
            size: 12,
            color: .secondaryLabelColor
        )

        let titleLabel = makeTextLabel("名称（可选）", size: 12, weight: .medium)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.placeholderString = "例如：收到、会议纪要"
        titleField.stringValue = existingItem?.title ?? ""
        titleField.font = .systemFont(ofSize: 13)
        window?.initialFirstResponder = titleField

        let contentLabel = makeTextLabel("内容", size: 12, weight: .medium)
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        let contentScrollView = NSScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.autohidesScrollers = true
        contentScrollView.borderType = .bezelBorder
        contentScrollView.drawsBackground = true
        contentScrollView.documentView = contentView

        contentView.isVerticallyResizable = true
        contentView.isHorizontallyResizable = false
        contentView.autoresizingMask = [.width]
        contentView.textContainer?.widthTracksTextView = true
        contentView.textContainer?.containerSize = NSSize(width: 444, height: CGFloat.greatestFiniteMagnitude)
        contentView.minSize = NSSize(width: 444, height: 110)
        contentView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        contentView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: 444,
                height: 110
            )
        )

        contentView.isRichText = false
        contentView.isEditable = true
        contentView.isSelectable = true
        contentView.importsGraphics = false
        contentView.font = .systemFont(ofSize: 13)
        contentView.textColor = .labelColor
        contentView.string = existingItem?.content ?? ""
        contentView.textContainerInset = NSSize(width: 8, height: 8)
        contentView.allowsUndo = true
        contentView.onTextChange = { [weak self] _ in
            self?.warningLabel.isHidden = true
        }

        let cancelButton = NSButton(
            title: "取消",
            target: self,
            action: #selector(cancelPressed)
        )
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let saveButton = NSButton(
            title: existingItem == nil ? "添加" : "保存",
            target: self,
            action: #selector(savePressed)
        )
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.hasDestructiveAction = false

        let buttons = NSStackView(views: [cancelButton, saveButton])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.orientation = .horizontal
        buttons.spacing = 10

        root.addSubview(heading)
        root.addSubview(categoryLabel)
        root.addSubview(titleLabel)
        root.addSubview(titleField)
        root.addSubview(contentLabel)
        root.addSubview(contentScrollView)
        root.addSubview(warningLabel)
        root.addSubview(buttons)

        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            heading.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),

            categoryLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            categoryLabel.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 6),

            titleLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 22),

            titleField.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            titleField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            titleField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            titleField.heightAnchor.constraint(equalToConstant: 28),

            contentLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            contentLabel.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 16),

            contentScrollView.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            contentScrollView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 6),
            contentScrollView.bottomAnchor.constraint(equalTo: warningLabel.topAnchor, constant: -12),
            contentScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 444),
            contentScrollView.heightAnchor.constraint(equalToConstant: 200),

            warningLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            warningLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            warningLabel.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -10),
            warningLabel.heightAnchor.constraint(equalToConstant: 16),

            buttons.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            buttons.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -22),
            buttons.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    @objc private func cancelPressed() {
        closeAsSheet()
    }

    @objc private func savePressed() {
        let content = contentView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            warningLabel.stringValue = "内容不能为空。请在内容框中输入，或使用 ⌘V / Ctrl+V 粘贴。"
            warningLabel.textColor = .systemRed
            warningLabel.isHidden = false
            NSSound.beep()
            window?.makeFirstResponder(contentView)
            return
        }

        warningLabel.isHidden = true

        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave?(title, content)
        onSave = nil
        closeAsSheet()
    }

    private func closeAsSheet() {
        if let sheetParent = window?.sheetParent, let window {
            sheetParent.endSheet(window)
        } else {
            close()
        }
    }
}
