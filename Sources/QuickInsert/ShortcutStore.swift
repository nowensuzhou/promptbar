import Foundation

final class ShortcutStore {
    static let shared = ShortcutStore()

    private(set) var categories: [ShortcutCategory] = []
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        let directory = applicationSupport.appendingPathComponent("QuickInsert", isDirectory: true)
        fileURL = directory.appendingPathComponent("shortcuts.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        load()
    }

    var firstCategoryID: UUID? {
        categories.first?.id
    }

    func category(withID id: UUID) -> ShortcutCategory? {
        categories.first { $0.id == id }
    }

    @discardableResult
    func addCategory(name: String) -> UUID? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }

        let category = ShortcutCategory(name: cleanName)
        categories.append(category)
        notifyChange()
        return category.id
    }

    @discardableResult
    func renameCategory(id: UUID, name: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, let index = categoryIndex(for: id) else { return false }

        categories[index].name = cleanName
        notifyChange()
        return true
    }

    @discardableResult
    func deleteCategory(id: UUID) -> Bool {
        guard categories.count > 1, let index = categoryIndex(for: id) else { return false }

        categories.remove(at: index)
        notifyChange()
        return true
    }

    @discardableResult
    func addItem(to categoryID: UUID, title: String, content: String) -> UUID? {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty, let index = categoryIndex(for: categoryID) else { return nil }

        let item = ShortcutItem(title: title, content: cleanContent)
        categories[index].items.append(item)
        notifyChange()
        return item.id
    }

    @discardableResult
    func updateItem(
        categoryID: UUID,
        itemID: UUID,
        title: String,
        content: String
    ) -> Bool {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanContent.isEmpty,
              let categoryIndex = categoryIndex(for: categoryID),
              let itemIndex = categories[categoryIndex].items.firstIndex(where: { $0.id == itemID })
        else {
            return false
        }

        categories[categoryIndex].items[itemIndex].title = title
        categories[categoryIndex].items[itemIndex].content = cleanContent
        notifyChange()
        return true
    }

    @discardableResult
    func deleteItem(categoryID: UUID, itemID: UUID) -> Bool {
        guard let categoryIndex = categoryIndex(for: categoryID),
              let itemIndex = categories[categoryIndex].items.firstIndex(where: { $0.id == itemID })
        else {
            return false
        }

        categories[categoryIndex].items.remove(at: itemIndex)
        notifyChange()
        return true
    }

    func save() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(categories)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("QuickInsert: unable to save shortcuts: \(error.localizedDescription)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            categories = try decoder.decode([ShortcutCategory].self, from: data)
            if categories.isEmpty {
                categories = Self.defaultCategories
                save()
            }
        } catch {
            categories = Self.defaultCategories
            save()
        }
    }

    private func categoryIndex(for id: UUID) -> Int? {
        categories.firstIndex { $0.id == id }
    }

    private func notifyChange() {
        save()
        NotificationCenter.default.post(name: .shortcutStoreDidChange, object: self)
    }

    private static var defaultCategories: [ShortcutCategory] {
        [
            ShortcutCategory(
                name: "常用",
                items: [
                    ShortcutItem(title: "收到", content: "好的，收到。"),
                    ShortcutItem(title: "感谢", content: "谢谢你的回复，我会尽快处理。"),
                    ShortcutItem(title: "稍后回复", content: "我现在有点忙，稍后回复你。")
                ]
            ),
            ShortcutCategory(
                name: "工作",
                items: [
                    ShortcutItem(title: "会议纪要", content: "会议纪要如下：\n\n1. \n2. \n3. "),
                    ShortcutItem(title: "进度同步", content: "同步一下当前进度：\n\n目前已完成：\n下一步计划：")
                ]
            )
        ]
    }
}
