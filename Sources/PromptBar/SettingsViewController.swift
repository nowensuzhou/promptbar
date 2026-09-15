import AppKit

final class CategoryRowView: NSTableCellView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor

        addSubview(nameLabel)
        addSubview(countLabel)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -8),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with category: ShortcutCategory) {
        nameLabel.stringValue = category.name
        countLabel.stringValue = "\(category.items.count)"
    }
}

final class SettingsItemRowView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let contentLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
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

        addSubview(labels)
        NSLayoutConstraint.activate([
            labels.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            labels.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
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

final class SettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: ShortcutStore
    private let sidebarTable = NSTableView()
    private let itemTable = NSTableView()
    private let categoryTitleLabel = NSTextField(labelWithString: "")
    private let itemCountLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "当前分类还没有快捷短语")

    private var selectedCategoryID: UUID?
    private var editorController: SnippetEditorWindowController?

    init(store: ShortcutStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        selectedCategoryID = store.firstCategoryID
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: .shortcutStoreDidChange,
            object: store
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view = root

        let splitView = NSSplitView()
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(makeSidebar())
        splitView.addArrangedSubview(makeMainContent())
        root.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: root.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            splitView.arrangedSubviews[0].widthAnchor.constraint(equalToConstant: 220)
        ])

        sidebarTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        refresh()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refresh()
    }

    @objc private func storeDidChange() {
        refresh()
    }

    @objc private func addCategoryPressed() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "新建分类"
        alert.informativeText = "为这组快捷短语设置一个名称。"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "例如：客户、代码、个人"
        alert.accessoryView = field
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn,
              let id = store.addCategory(name: field.stringValue)
        else {
            return
        }

        selectedCategoryID = id
        refresh()
    }

    @objc private func renameCategoryPressed() {
        guard let category = selectedCategory else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "重命名分类"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = category.name
        alert.accessoryView = field
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.renameCategory(id: category.id, name: field.stringValue)
    }

    @objc private func deleteCategoryPressed() {
        guard let category = selectedCategory else { return }

        if store.categories.count <= 1 {
            showMessage(
                title: "无法删除分类",
                text: "至少需要保留一个分类。"
            )
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "删除“\(category.name)”？"
        alert.informativeText = "该分类下的快捷短语也会一起删除。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.deleteCategory(id: category.id)
        selectedCategoryID = store.firstCategoryID
        refresh()
    }

    @objc private func addItemPressed() {
        guard let category = selectedCategory else { return }
        presentEditor(for: category, item: nil)
    }

    @objc private func editSelectedItem() {
        guard let category = selectedCategory,
              itemTable.selectedRow >= 0,
              category.items.indices.contains(itemTable.selectedRow)
        else {
            return
        }

        presentEditor(for: category, item: category.items[itemTable.selectedRow])
    }

    @objc private func insertSelectedItem() {
        guard let category = selectedCategory,
              itemTable.selectedRow >= 0,
              category.items.indices.contains(itemTable.selectedRow)
        else { return }

        let item = category.items[itemTable.selectedRow]
        PasteService.shared.insert(item.content, into: nil) { [weak self] in
            guard let window = self?.view.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func deleteSelectedItem() {
        guard let category = selectedCategory,
              itemTable.selectedRow >= 0,
              category.items.indices.contains(itemTable.selectedRow)
        else {
            return
        }

        let item = category.items[itemTable.selectedRow]
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "删除“\(item.displayTitle)”？"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.deleteItem(categoryID: category.id, itemID: item.id)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === sidebarTable {
            return store.categories.count
        }
        return selectedCategory?.items.count ?? 0
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor _: NSTableColumn?,
        row: Int
    ) -> NSView? {
        if tableView === sidebarTable {
            let view = CategoryRowView(frame: .zero)
            view.configure(with: store.categories[row])
            return view
        }

        guard let item = selectedCategory?.items[row] else { return nil }
        let view = SettingsItemRowView(frame: .zero)
        view.configure(with: item)
        return view
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView,
              tableView === sidebarTable
        else {
            return
        }

        let row = sidebarTable.selectedRow
        guard store.categories.indices.contains(row) else { return }
        selectedCategoryID = store.categories[row].id
        refreshItems()
    }

    private var selectedCategory: ShortcutCategory? {
        selectedCategoryID.flatMap(store.category(withID:))
    }

    private func refresh() {
        guard isViewLoaded else { return }

        if let selectedCategoryID,
           let row = store.categories.firstIndex(where: { $0.id == selectedCategoryID }) {
            sidebarTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else {
            selectedCategoryID = store.firstCategoryID
            if !store.categories.isEmpty {
                sidebarTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
        }

        sidebarTable.reloadData()
        refreshItems()
    }

    private func refreshItems() {
        guard isViewLoaded else { return }

        let category = selectedCategory
        categoryTitleLabel.stringValue = category?.name ?? "快捷短语"
        itemCountLabel.stringValue = "\(category?.items.count ?? 0) 条"
        itemTable.reloadData()
        emptyLabel.isHidden = !(category?.items.isEmpty ?? true)

        if let category, !category.items.isEmpty {
            itemTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        } else {
            itemTable.deselectAll(nil)
        }
    }

    private func makeSidebar() -> NSView {
        let container = NSVisualEffectView()
        container.material = .sidebar
        container.blendingMode = .behindWindow
        container.state = .active
        container.translatesAutoresizingMaskIntoConstraints = false

        let heading = makeTextLabel("分类", size: 17, weight: .bold)
        let addButton = makeIconButton(
            symbolName: "plus",
            tooltip: "新建分类",
            target: self,
            action: #selector(addCategoryPressed)
        )

        let headingRow = NSView()
        headingRow.translatesAutoresizingMaskIntoConstraints = false
        headingRow.addSubview(heading)
        headingRow.addSubview(addButton)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: headingRow.leadingAnchor, constant: 18),
            heading.centerYAnchor.constraint(equalTo: headingRow.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: headingRow.trailingAnchor, constant: -12),
            addButton.centerYAnchor.constraint(equalTo: headingRow.centerYAnchor)
        ])

        configureSidebarTable()
        let scrollView = makeScrollView(for: sidebarTable)

        let renameButton = makeIconButton(
            symbolName: "pencil",
            tooltip: "重命名分类",
            target: self,
            action: #selector(renameCategoryPressed)
        )
        let deleteButton = makeIconButton(
            symbolName: "trash",
            tooltip: "删除分类",
            target: self,
            action: #selector(deleteCategoryPressed)
        )
        let actions = NSStackView(views: [renameButton, deleteButton])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.orientation = .horizontal
        actions.spacing = 4

        container.addSubview(headingRow)
        container.addSubview(scrollView)
        container.addSubview(actions)
        NSLayoutConstraint.activate([
            headingRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headingRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headingRow.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            headingRow.heightAnchor.constraint(equalToConstant: 34),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: headingRow.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: actions.topAnchor, constant: -8),

            actions.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            actions.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            actions.heightAnchor.constraint(equalToConstant: 30)
        ])
        return container
    }

    private func makeMainContent() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let heading = makeTextLabel("", size: 21, weight: .bold)
        categoryTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryTitleLabel.font = heading.font
        categoryTitleLabel.textColor = heading.textColor

        itemCountLabel.translatesAutoresizingMaskIntoConstraints = false
        itemCountLabel.font = .systemFont(ofSize: 12)
        itemCountLabel.textColor = .secondaryLabelColor

        let addButton = NSButton(
            title: "添加短语",
            target: self,
            action: #selector(addItemPressed)
        )
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.image = NSImage(
            systemSymbolName: "plus",
            accessibilityDescription: "添加短语"
        )
        addButton.imagePosition = .imageLeading
        addButton.bezelStyle = .rounded
        addButton.controlSize = .regular

        let insertButton = NSButton(
            title: "插入",
            target: self,
            action: #selector(insertSelectedItem)
        )
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.image = NSImage(
            systemSymbolName: "paperplane",
            accessibilityDescription: "插入到上一个应用"
        )
        insertButton.imagePosition = .imageLeading
        insertButton.bezelStyle = .rounded
        insertButton.controlSize = .regular

        let editButton = makeIconButton(
            symbolName: "pencil",
            tooltip: "编辑短语",
            target: self,
            action: #selector(editSelectedItem)
        )
        let deleteButton = makeIconButton(
            symbolName: "trash",
            tooltip: "删除短语",
            target: self,
            action: #selector(deleteSelectedItem)
        )

        let headingStack = NSStackView(views: [categoryTitleLabel, itemCountLabel])
        headingStack.translatesAutoresizingMaskIntoConstraints = false
        headingStack.orientation = .vertical
        headingStack.alignment = .leading
        headingStack.spacing = 5

        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(headingStack)
        toolbar.addSubview(addButton)
        toolbar.addSubview(insertButton)
        toolbar.addSubview(editButton)
        toolbar.addSubview(deleteButton)
        NSLayoutConstraint.activate([
            headingStack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 28),
            headingStack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            deleteButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -24),
            deleteButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -4),
            editButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -10),
            addButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),

            insertButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -10),
            insertButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor)
        ])

        configureItemTable()
        let scrollView = makeScrollView(for: itemTable)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.alignment = .center
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor

        let emptyContainer = NSView()
        emptyContainer.translatesAutoresizingMaskIntoConstraints = false
        emptyContainer.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: emptyContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: emptyContainer.centerYAnchor)
        ])

        let separator = makeSeparator()
        container.addSubview(toolbar)
        container.addSubview(separator)
        container.addSubview(scrollView)
        container.addSubview(emptyContainer)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: container.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 76),

            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.topAnchor.constraint(equalTo: toolbar.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            emptyContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            emptyContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            emptyContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            emptyContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
        return container
    }

    private func configureSidebarTable() {
        sidebarTable.headerView = nil
        sidebarTable.backgroundColor = .clear
        sidebarTable.rowHeight = 38
        sidebarTable.intercellSpacing = .zero
        sidebarTable.selectionHighlightStyle = .regular
        sidebarTable.dataSource = self
        sidebarTable.delegate = self
        sidebarTable.target = self
        sidebarTable.doubleAction = #selector(renameCategoryPressed)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Category"))
        column.resizingMask = .autoresizingMask
        sidebarTable.addTableColumn(column)
    }

    private func configureItemTable() {
        itemTable.headerView = nil
        itemTable.backgroundColor = .clear
        itemTable.rowHeight = 64
        itemTable.intercellSpacing = .zero
        itemTable.selectionHighlightStyle = .regular
        itemTable.dataSource = self
        itemTable.delegate = self
        itemTable.target = self
        itemTable.doubleAction = #selector(insertSelectedItem)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Shortcut"))
        column.resizingMask = .autoresizingMask
        itemTable.addTableColumn(column)
    }

    private func presentEditor(for category: ShortcutCategory, item: ShortcutItem?) {
        guard let parentWindow = view.window else { return }

        let editor = SnippetEditorWindowController(
            categoryName: category.name,
            item: item
        ) { [weak self] title, content in
            guard let self else { return }

            if let item {
                store.updateItem(
                    categoryID: category.id,
                    itemID: item.id,
                    title: title,
                    content: content
                )
            } else {
                store.addItem(
                    to: category.id,
                    title: title,
                    content: content
                )
            }
        }
        editorController = editor

        guard let sheet = editor.window else { return }
        parentWindow.beginSheet(sheet) { [weak self] _ in
            self?.editorController = nil
        }
    }

    private func showMessage(title: String, text: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
