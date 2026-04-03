import Foundation
import Testing
@testable import MELISearch

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
        let updatedAt = Date(timeIntervalSinceReferenceDate: 123_456)
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                #expect(query == "iPhone")
                return [expectedProduct]
            }),
            configuration: .preview,
            dateProvider: { updatedAt }
        )

        viewModel.query = "iPhone"
        await viewModel.search()

        #expect(viewModel.state == SearchViewModel.State.loaded)
        #expect(viewModel.lastSubmittedQuery == "iPhone")
        #expect(viewModel.lastUpdatedAt == updatedAt)
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
        let updatedAt = Date(timeIntervalSinceReferenceDate: 654_321)
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                #expect(query == "Garmin")
                return []
            }),
            configuration: .preview,
            dateProvider: { updatedAt }
        )

        viewModel.query = "Garmin"
        await viewModel.search()

        #expect(viewModel.state == SearchViewModel.State.empty)
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.lastSubmittedQuery == "Garmin")
        #expect(viewModel.lastUpdatedAt == updatedAt)
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
        #expect(viewModel.lastUpdatedAt == nil)
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
        let dateProvider = TestDateProvider(
            values: [
                Date(timeIntervalSinceReferenceDate: 1_000),
                Date(timeIntervalSinceReferenceDate: 2_000)
            ]
        )
        let viewModel = SearchViewModel(
            repository: .mock(search: { query in
                await recorder.append(query)
                return [TestFixtures.summary]
            }),
            configuration: .preview,
            dateProvider: dateProvider.next
        )

        viewModel.query = "iPhone"
        await viewModel.search()
        viewModel.query = "Sony"
        await viewModel.repeatLastSearch()

        #expect(viewModel.query == "iPhone")
        #expect(viewModel.lastUpdatedAt == Date(timeIntervalSinceReferenceDate: 2_000))
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
        let updatedAt = Date(timeIntervalSinceReferenceDate: 999_999)
        let viewModel = SearchViewModel(
            repository: .mock(search: { _ in
                throw AppError.forbidden
            }),
            configuration: .preview,
            dateProvider: { updatedAt }
        )

        viewModel.query = "iPhone"
        await viewModel.search()

        #expect(viewModel.state == SearchViewModel.State.failed(AppError.forbidden))
        #expect(viewModel.results.isEmpty)
        #expect(viewModel.lastUpdatedAt == nil)
    }
}

private actor SearchQueryRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

@MainActor
private final class TestDateProvider {
    private var values: [Date]

    init(values: [Date]) {
        self.values = values
    }

    func next() -> Date {
        values.removeFirst()
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
