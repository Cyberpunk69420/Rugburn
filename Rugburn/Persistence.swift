import Foundation

enum Persistence {
    static let itemsKey = "Rugburn.items"

    static func saveItems(_ items: [WebAppItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: itemsKey)
        } catch {
            print("Failed to save items: \(error)")
        }
    }

    static func loadItems() -> [WebAppItem] {
        guard let data = UserDefaults.standard.data(forKey: itemsKey) else { return [] }
        do {
            let items = try JSONDecoder().decode([WebAppItem].self, from: data)
            return items
        } catch {
            print("Failed to load items: \(error)")
            return []
        }
    }
}
