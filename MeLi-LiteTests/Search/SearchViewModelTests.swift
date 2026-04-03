import Testing
@testable import MeLi_Lite

@MainActor
struct SearchViewModelTests {
    @Test
    func blankQueryKeepsIdleState() async {
        let viewModel = SearchViewModel(
            repository: .mock(),
            configuration: .preview
        )

        viewModel.query = "   "
        await viewModel.search()

        #expect(viewModel.state == .idle)
        #expect(viewModel.results.isEmpty)
    }

    @Test
    func successfulSearchStoresResults() async {
        let expectedProduct = TestFixtures.summary
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                #expect(query == "iphone")
                return [expectedProduct]
            }),
            configuration: .preview
        )

        viewModel.query = "iphone"
        await viewModel.search()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.lastSubmittedQuery == "iphone")
        #expect(viewModel.results == [expectedProduct])
    }

    @Test
    func failedSearchSurfacesMappedError() async {
        let viewModel = SearchViewModel(
            repository: .mock(search: { _ in
                throw AppError.forbidden
            }),
            configuration: .preview
        )

        viewModel.query = "iphone"
        await viewModel.search()

        #expect(viewModel.state == .failed(.forbidden))
        #expect(viewModel.results.isEmpty)
    }
}

private enum TestFixtures {
    static let summary = ProductSummary(
        id: "ITEM-1",
        title: "iPhone 15 Pro",
        subtitle: "Test device",
        price: 10,
        currencyCode: "ARS",
        thumbnailURL: nil,
        permalinkURL: nil,
        condition: "new",
        availableQuantity: 1,
        soldQuantity: 1,
        attributes: [ProductAttribute(id: "BRAND", name: "Brand", value: "Apple")],
        shipping: ShippingInfo(isFreeShipping: true, isStorePickupAvailable: false)
    )
}

private extension ProductRepository {
    static func mock(
        search: @escaping (String) async throws -> [ProductSummary] = { _ in [] },
        detail: @escaping (String) async throws -> ProductDetail = { _ in
            throw AppError.unknown("No detail stub was provided.")
        }
    ) -> ProductRepository {
        ProductRepository(search: search, detail: detail)
    }
}
