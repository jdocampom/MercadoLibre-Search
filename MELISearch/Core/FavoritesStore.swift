import Foundation
import Observation

@MainActor
@Observable
/// Persists user-selected favorite products so they are available across app launches.
final class FavoritesStore {
    /// Favorites shown by the dedicated favorites screen.
    private(set) var favorites: [ProductSummary]

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let favoritesKey: String
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()

    /// Creates a favorites store backed by `UserDefaults`.
    /// - Parameters:
    ///   - userDefaults: Persistence container used to store serialized favorites.
    ///   - favoritesKey: Storage key used for the serialized favorites payload.
    init(
        userDefaults: UserDefaults = .standard,
        favoritesKey: String = "com.jdocampo.MeLi-Lite.favorites"
    ) {
        self.userDefaults = userDefaults
        self.favoritesKey = favoritesKey
        favorites = Self.loadFavorites(from: userDefaults, key: favoritesKey)
    }

    /// Indicates whether the given product is already saved as a favorite.
    /// - Parameter product: Product to check.
    /// - Returns: `true` when the product is already saved.
    func contains(_ product: ProductSummary) -> Bool {
        favorites.contains(where: { $0.id == product.id })
    }

    /// Adds or refreshes a favorite product and moves it to the front of the list.
    /// - Parameter product: Product summary selected by the user.
    func add(_ product: ProductSummary) {
        favorites.removeAll(where: { $0.id == product.id })
        favorites.insert(product, at: 0)
        persistFavorites()
    }

    /// Removes a favorite product using its stable identifier.
    /// - Parameter id: Product identifier to remove.
    func remove(id: String) {
        let originalCount = favorites.count
        favorites.removeAll(where: { $0.id == id })

        guard favorites.count != originalCount else {
            return
        }

        persistFavorites()
    }

    /// Removes a favorite product when it is already present.
    /// - Parameter product: Product to remove.
    func remove(_ product: ProductSummary) {
        remove(id: product.id)
    }

    /// Toggles the favorite state for the given product.
    /// - Parameter product: Product selected in the UI.
    func toggle(_ product: ProductSummary) {
        if contains(product) {
            remove(product)
        } else {
            add(product)
        }
    }
}

private extension FavoritesStore {
    /// Restores serialized favorites from `UserDefaults`.
    /// - Parameters:
    ///   - userDefaults: Persistence container used by the store.
    ///   - key: Storage key that may contain serialized favorites.
    /// - Returns: The restored favorites or an empty array when decoding fails.
    static func loadFavorites(from userDefaults: UserDefaults, key: String) -> [ProductSummary] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        return (try? JSONDecoder().decode([ProductSummary].self, from: data)) ?? []
    }

    /// Saves the in-memory favorites snapshot to `UserDefaults`.
    func persistFavorites() {
        guard let data = try? encoder.encode(favorites) else {
            return
        }

        userDefaults.set(data, forKey: favoritesKey)
    }
}
