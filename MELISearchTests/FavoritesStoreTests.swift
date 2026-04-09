import Foundation
import Testing
@testable import MELISearch

@MainActor
struct FavoritesStoreTests {
    @Test
    func addPersistsFavoriteAcrossStoreReloads() {
        let userDefaults = makeUserDefaults()
        let store = FavoritesStore(userDefaults: userDefaults, favoritesKey: "favorites")

        store.add(TestFixtures.summary)

        #expect(store.favorites == [TestFixtures.summary])

        let reloadedStore = FavoritesStore(userDefaults: userDefaults, favoritesKey: "favorites")
        #expect(reloadedStore.favorites == [TestFixtures.summary])
    }

    @Test
    func toggleRemovesExistingFavorite() {
        let store = FavoritesStore(userDefaults: makeUserDefaults(), favoritesKey: "favorites")

        store.add(TestFixtures.summary)
        store.toggle(TestFixtures.summary)

        #expect(store.favorites.isEmpty)
    }

    @Test
    func addMovesUpdatedFavoriteToFrontWithoutDuplicates() {
        let store = FavoritesStore(userDefaults: makeUserDefaults(), favoritesKey: "favorites")

        store.add(TestFixtures.summary)
        store.add(TestFixtures.secondSummary)
        store.add(TestFixtures.summary)

        #expect(store.favorites.map(\.id) == ["ITEM-1", "ITEM-2"])
    }
}

private extension FavoritesStoreTests {
    func makeUserDefaults() -> UserDefaults {
        let suiteName = "FavoritesStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }
}

private enum TestFixtures {
    static let summary = ProductSummary(
        id: "ITEM-1",
        title: "iPhone 15 Pro",
        subtitle: "Phone",
        price: 10,
        currencyCode: "COP",
        thumbnailURL: nil,
        permalinkURL: nil,
        condition: "new",
        availableQuantity: 1,
        soldQuantity: 2,
        attributes: [ProductAttribute(id: "BRAND", name: "Brand", value: "Apple")],
        shipping: ShippingInfo(isFreeShipping: true, isStorePickupAvailable: false)
    )

    static let secondSummary = ProductSummary(
        id: "ITEM-2",
        title: "Sony WH-1000XM5",
        subtitle: "Headphones",
        price: 20,
        currencyCode: "COP",
        thumbnailURL: nil,
        permalinkURL: nil,
        condition: "new",
        availableQuantity: 3,
        soldQuantity: 4,
        attributes: [ProductAttribute(id: "BRAND", name: "Brand", value: "Sony")],
        shipping: ShippingInfo(isFreeShipping: false, isStorePickupAvailable: false)
    )
}
