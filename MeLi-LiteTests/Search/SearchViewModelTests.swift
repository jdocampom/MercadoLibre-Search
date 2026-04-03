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
                #expect(query == "iPhone")
                return [expectedProduct]
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.lastSubmittedQuery == "iPhone")
        #expect(viewModel.results == [expectedProduct])
    }

    @Test
    func trimsWhitespaceBeforeExecutingSearch() async {
        let recorder = SearchQueryRecorder()
        let expectedProduct = TestFixtures.summary
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                await recorder.append(query)
                return [expectedProduct]
            }),
            configuration: .preview
        )

        viewModel.query = "   iPhone   "
        await viewModel.search()

        #expect(viewModel.query == "iPhone")
        #expect(viewModel.lastSubmittedQuery == "iPhone")
        #expect(await recorder.values == ["iPhone"])
    }

    @Test
    func emptySearchResultsUseEmptyState() async {
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                #expect(query == "Garmin")
                return []
            }),
            configuration: .preview
        )

        viewModel.query = "Garmin"
        await viewModel.search()

        #expect(viewModel.state == .empty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.lastSubmittedQuery == "Garmin")
    }

    @Test
    func clearingQueryRestoresIdleState() async {
        let expectedProduct = TestFixtures.summary
        let viewModel = SearchViewModel(
            repository: .mock(search: { _ in [expectedProduct] }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()
        viewModel.query = ""

        #expect(viewModel.state == .idle)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.lastSubmittedQuery.isEmpty)
    }

    @Test
    func repeatLastSearchDoesNothingWithoutPreviousQuery() async {
        let recorder = SearchQueryRecorder()
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                await recorder.append(query)
                return [TestFixtures.summary]
            }),
            configuration: .preview
        )

        await viewModel.repeatLastSearch()

        #expect(viewModel.state == .idle)
        #expect(await recorder.values.isEmpty)
    }

    @Test
    func repeatLastSearchReplaysLastSubmittedQuery() async {
        let recorder = SearchQueryRecorder()
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                await recorder.append(query)
                return [TestFixtures.summary]
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()
        viewModel.query = "Sony"
        await viewModel.repeatLastSearch()

        #expect(viewModel.query == "iPhone")
        #expect(await recorder.values == ["iPhone", "iPhone"])
    }

    @Test
    func applySuggestionUpdatesQueryAndTriggersSearch() async {
        let recorder = SearchQueryRecorder()
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                await recorder.append(query)
                return [TestFixtures.summary]
            }),
            configuration: .preview
        )

        await viewModel.applySuggestion("Kindle")

        #expect(viewModel.query == "Kindle")
        #expect(viewModel.lastSubmittedQuery == "Kindle")
        #expect(viewModel.state == .loaded)
        #expect(await recorder.values == ["Kindle"])
    }

    @Test
    func clearingQueryInvalidatesInFlightSearchResults() async throws {
        let expectedProduct = TestFixtures.summary
        let viewModel = SearchViewModel(
            repository: .mock(search: { _ in
                try await Task.sleep(for: .milliseconds(100))
                return [expectedProduct]
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        let searchTask = Task {
            await viewModel.search()
        }

        try await Task.sleep(for: .milliseconds(20))
        viewModel.query = ""
        await searchTask.value

        #expect(viewModel.state == .idle)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.lastSubmittedQuery.isEmpty)
    }

    @Test
    func isLoadingReflectsInFlightLifecycle() async throws {
        let viewModel = SearchViewModel(
            repository: .mock(search: { _ in
                try await Task.sleep(for: .milliseconds(100))
                return [TestFixtures.summary]
            }),
            configuration: .preview
        )

        viewModel.query = "Speaker"
        let searchTask = Task {
            await viewModel.search()
        }

        await Task.yield()

        #expect(viewModel.isLoading)

        await searchTask.value

        #expect(viewModel.isLoading == false)
        #expect(viewModel.state == .loaded)
    }

    @Test
    func failedSearchSurfacesMappedError() async {
        let viewModel = SearchViewModel(
            repository: .mock(search: { _ in
                throw AppError.forbidden
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()

        #expect(viewModel.state == .failed(.forbidden))
        #expect(viewModel.results.isEmpty)
    }
}

private actor SearchQueryRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
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
