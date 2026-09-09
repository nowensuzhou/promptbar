import Foundation

struct ShortcutItem: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var content: String

    init(id: UUID = UUID(), title: String = "", content: String) {
        self.id = id
        self.title = title
        self.content = content
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let firstLine = content.components(separatedBy: .newlines).first ?? content
        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var preview: String {
        content.replacingOccurrences(of: "\n", with: " ")
    }
}

struct ShortcutCategory: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var items: [ShortcutItem]

    init(id: UUID = UUID(), name: String, items: [ShortcutItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}

extension Notification.Name {
    static let shortcutStoreDidChange = Notification.Name("QuickInsertShortcutStoreDidChange")
}
