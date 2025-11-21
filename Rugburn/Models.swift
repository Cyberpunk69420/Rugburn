import Foundation
import SwiftUI
import Combine

struct WebAppItem: Identifiable, Codable, Equatable {
    var id: UUID = .init()
    var name: String
    var url: URL
    var iconSymbol: String?
    var userAgent: String?
    var iconData: Data? // Optional favicon or custom icon
}

struct UserSettings: Codable {
    var defaultURL: URL = URL(string: "https://www.google.com")!
}

class SidebarViewModel: ObservableObject {
    @Published var items: [WebAppItem] = []
    @Published var selected: WebAppItem? = nil
    @Published var addName: String = ""
    @Published var addUrl: String = ""
    @Published var showAddSheet: Bool = false
    @Published var useMobileUserAgent: Bool = true

    init() {
        let loaded = Persistence.loadItems()
        if loaded.isEmpty {
            items = [
                WebAppItem(name: "Google", url: URL(string: "https://www.google.com")!, iconSymbol: "globe", userAgent: nil),
                WebAppItem(name: "YouTube", url: URL(string: "https://www.youtube.com")!, iconSymbol: "play.rectangle", userAgent: nil)
            ]
        } else {
            items = loaded
        }
        selected = items.first
    }

    func addItem() {
        let raw = addUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addName.isEmpty,
              !raw.isEmpty,
              let url = URL(string: normalizedUrlString(raw)) else {
            Logger.log("Invalid URL or empty name for new sidebar item", level: .warning)
            return
        }
        let item = WebAppItem(name: addName, url: url, iconSymbol: nil, userAgent: nil)
        items.append(item)
        Persistence.saveItems(items)
        selected = item
        addName = ""
        addUrl = ""
        showAddSheet = false
    }

    func normalizedUrlString(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return trimmed }
        return "https://" + trimmed
    }

    func delete(_ item: WebAppItem) {
        if let idx = items.firstIndex(of: item) {
            items.remove(at: idx)
            Persistence.saveItems(items)
            if selected?.id == item.id {
                selected = items.first
            }
        }
    }
}
