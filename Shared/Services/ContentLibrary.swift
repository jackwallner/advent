import Foundation

/// The bundled items from content/items.json, in file order (order matters for gift-link parity with the web).
struct ContentLibrary: Sendable {
    let items: [Item]
    let byID: [String: Item]

    init(items: [Item]) {
        self.items = items
        self.byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    static let bundled: ContentLibrary = {
        guard let url = Bundle.main.url(forResource: "items", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([Item].self, from: data) else {
            assertionFailure("items.json missing from the bundle")
            return ContentLibrary(items: [])
        }
        return ContentLibrary(items: items)
    }()
}
