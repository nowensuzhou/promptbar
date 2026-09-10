import AppKit

final class PaletteRowView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let contentLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(
            systemSymbolName: "text.quote",
            accessibilityDescription: "快捷短语"
        )
        iconView.contentTintColor = .controlAccentColor
        iconView.imageScaling = .scaleProportionallyUpOrDown

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.font = .systemFont(ofSize: 12)
        contentLabel.textColor = .secondaryLabelColor
        contentLabel.lineBreakMode = .byTruncatingTail

        let labels = NSStackView(views: [titleLabel, contentLabel])
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 4

        addSubview(iconView)
        addSubview(labels)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            labels.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            labels.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: ShortcutItem) {
        titleLabel.stringValue = item.displayTitle
        contentLabel.stringValue = item.preview
    }
}

final class PaletteViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let store: ShortcutStore
    private let categoryPopup = NSPopUpButton()
    private let searchField = NSSearchField()
    private let tableView = ClickableTableView()
    private let emptyLabel = NSTextField(labelWithString: "当前分类还没有快捷短语")
    private let countLabel = NSTextField(labelWithString: "")
    private var selectedCategoryID: UUID?
    private var visibleItems: [ShortcutItem] = []

    var onInsert: ((String) -> Void)?
    var onRequestSettings: (() -> Void)?
    var onClose: (() -> Void)?

    init(store: ShortcutStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = NSVisualEffectView()
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .active
        root.wantsLayer = true
        root.layer?.cornerRadius = 16
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        view = root

        let header = makeHeader()
        let controls = makeControls()
        let tableContainer = makeTableContainer()
        let footer = makeFooter()

        let stack = NSStackView(views: [header, controls, tableContainer, footer])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            header.heightAnchor.constraint(equalToConstant: 78),
            controls.heightAnchor.constraint(equalToConstant: 54),
            footer.heightAnchor.constraint(equalToConstant: 40)
        ])

        tableView.onClickRow = { [weak self] row in
            self?.insertItem(at: row)
        }
        searchField.delegate = self
        refresh()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refresh()
    }

    func refresh() {
        guard isViewLoaded else { return }

        updateCategoryPopup()
        let category = selectedCategoryID.flatMap(store.category(withID:))
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        visibleItems = (category?.items ?? []).filter { item in
            guard !query.isEmpty else { return true }
            return item.displayTitle.localizedCaseInsensitiveContains(query)
                || item.content.localizedCaseInsensitiveContains(query)
        }

        tableView.reloadData()
        countLabel.stringValue = "\(visibleItems.count) 条"
        emptyLabel.isHidden = !visibleItems.isEmpty

        if visibleItems.isEmpty {
            tableView.deselectAll(nil)
        } else {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func focusSearch() {
        view.window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:
            onClose?()
            return true
        case 36, 76:
            guard let row = selectedRow() else { return true }
            insertItem(at: row)
            return true
        case 125:
            moveSelection(by: 1)
            return true
        case 126:
            moveSelection(by: -1)
            return true
        default:
            return false
        }
    }

    func numberOfRows(in _: NSTableView) -> Int {
        visibleItems.count
    }

    func tableView(
        _: NSTableView,
        viewFor _: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("PaletteRow")
        let rowView = PaletteRowView(frame: .zero)
        rowView.identifier = identifier
        rowView.configure(with: visibleItems[row])
        return rowView
    }

    func controlTextDidChange(_: Notification) {
        refresh()
    }

    @objc private func categoryChanged() {
        guard let represented = categoryPopup.selectedItem?.representedObject as? String,
              let id = UUID(uuidString: represented)
        else {
            return
        }

        selectedCategoryID = id
        refresh()
    }

    @objc private func closeButtonPressed() {
        onClose?()
    }

    @objc private func settingsButtonPressed() {
        onRequestSettings?()
    }

    private func makeHeader() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(
            systemSymbolName: "text.badge.plus",
            accessibilityDescription: "PromptBar"
        )
        iconView.contentTintColor = .controlAccentColor
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let title = makeTextLabel("PromptBar", size: 20, weight: .bold)
        let subtitle = makeTextLabel(
            "从当前分类选择一条短语",
            size: 12,
            color: .secondaryLabelColor
        )
        let titles = NSStackView(views: [title, subtitle])
        titles.translatesAutoresizingMaskIntoConstraints = false
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 5

        let closeButton = makeIconButton(
            symbolName: "xmark",
            tooltip: "关闭",
            target: self,
            action: #selector(closeButtonPressed)
        )

        container.addSubview(iconView)
        container.addSubview(titles)
        container.addSubview(closeButton)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),

            titles.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titles.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titles.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -12),

            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            closeButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func makeControls() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let categoryLabel = makeTextLabel("分类", size: 12, weight: .medium, color: .secondaryLabelColor)
        categoryPopup.translatesAutoresizingMaskIntoConstraints = false
        categoryPopup.target = self
        categoryPopup.action = #selector(categoryChanged)
        categoryPopup.font = .systemFont(ofSize: 13)
        categoryPopup.setContentHuggingPriority(.required, for: .horizontal)
        categoryPopup.setContentCompressionResistancePriority(.required, for: .horizontal)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "搜索快捷短语"
        searchField.controlSize = .regular
        searchField.focusRingType = .default

        container.addSubview(categoryLabel)
        container.addSubview(categoryPopup)
        container.addSubview(searchField)
        NSLayoutConstraint.activate([
            categoryLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            categoryLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            categoryPopup.leadingAnchor.constraint(equalTo: categoryLabel.trailingAnchor, constant: 8),
            categoryPopup.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            categoryPopup.widthAnchor.constraint(equalToConstant: 142),

            searchField.leadingAnchor.constraint(equalTo: categoryPopup.trailingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            searchField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 28)
        ])
        return container
    }

    private func makeTableContainer() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 64
        tableView.intercellSpacing = .zero
        tableView.selectionHighlightStyle = .regular
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.dataSource = self
        tableView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Shortcut"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        let scrollView = makeScrollView(for: tableView)
        let emptyContainer = NSView()
        emptyContainer.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyContainer.addSubview(emptyLabel)

        container.addSubview(scrollView)
        container.addSubview(emptyContainer)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            emptyContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            emptyContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            emptyContainer.topAnchor.constraint(equalTo: container.topAnchor),
            emptyContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: emptyContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: emptyContainer.centerYAnchor)
        ])
        return container
    }

    private func makeFooter() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let separator = makeSeparator()
        let settingsButton = makeIconButton(
            symbolName: "gearshape",
            tooltip: "打开设置",
            target: self,
            action: #selector(settingsButtonPressed)
        )
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .tertiaryLabelColor

        container.addSubview(separator)
        container.addSubview(settingsButton)
        container.addSubview(countLabel)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.topAnchor.constraint(equalTo: container.topAnchor),

            settingsButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            settingsButton.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 4),

            countLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            countLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 4)
        ])
        return container
    }

    private func updateCategoryPopup() {
        let currentID = selectedCategoryID
        categoryPopup.removeAllItems()

        for category in store.categories {
            categoryPopup.addItem(withTitle: category.name)
            categoryPopup.lastItem?.representedObject = category.id.uuidString
        }

        if let currentID,
           let index = store.categories.firstIndex(where: { $0.id == currentID }) {
            selectedCategoryID = currentID
            categoryPopup.selectItem(at: index)
        } else if let first = store.categories.first {
            selectedCategoryID = first.id
            categoryPopup.selectItem(at: 0)
        } else {
            selectedCategoryID = nil
        }
    }

    private func selectedRow() -> Int? {
        let row = tableView.selectedRow
        return row >= 0 && row < visibleItems.count ? row : nil
    }

    private func moveSelection(by offset: Int) {
        guard !visibleItems.isEmpty else { return }

        let current = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let next = min(max(current + offset, 0), visibleItems.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func insertItem(at row: Int) {
        guard visibleItems.indices.contains(row) else { return }
        onInsert?(visibleItems[row].content)
    }
}
