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
    var faviconFileName: String? // Cached favicon file name (in Caches/RugburnFavicons)
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

    private let faviconService = FaviconService.shared

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

        refreshFaviconsIfNeeded()
    }

    private func refreshFaviconsIfNeeded() {
        for index in items.indices {
            if items[index].faviconFileName == nil {
                fetchFavicon(forIndex: index)
            }
        }
    }

    private func fetchFavicon(forIndex index: Int, forceRefresh: Bool = false) {
        let item = items[index]
        faviconService.fetchFavicon(for: item, forceRefresh: forceRefresh) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self,
                      index < self.items.count,
                      self.items[index].id == item.id else { return }

                switch result {
                case .success(let payload):
                    guard let payload = payload else { return }
                    self.items[index].faviconFileName = payload.fileName
                    Persistence.saveItems(self.items)

                case .failure:
                    // Error already logged inside service; keep using fallback icon.
                    break
                }
            }
        }
    }

    /// Public helper so other parts of the app (e.g. star/bookmark button) can trigger a favicon fetch
    func fetchFaviconIfNeeded(for item: WebAppItem, forceRefresh: Bool = false) {
        guard let index = items.firstIndex(of: item) else { return }
        if !forceRefresh, items[index].faviconFileName != nil { return }
        fetchFavicon(forIndex: index, forceRefresh: forceRefresh)
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
        if let idx = items.firstIndex(of: item) {
            fetchFavicon(forIndex: idx)
        }
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
            if let fileName = items[idx].faviconFileName {
                FaviconCache.shared.removeFavicon(named: fileName)
            }
            items.remove(at: idx)
            Persistence.saveItems(items)
            if selected?.id == item.id {
                selected = items.first
            }
        }
    }
}
