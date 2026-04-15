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

    @Test
    func firstPageRequestsZeroOffsetWithPageSizeLimit() async {
        let recorder = PaginationRequestRecorder()
        let viewModel = SearchViewModel(
            repository: .pagedMock(search: { query, offset, limit in
                await recorder.record(query: query, offset: offset, limit: limit)
                return ProductSearchPage(
                    items: (0 ..< 10).map { index in TestFixtures.summary(id: "FIRST-\(index)") },
                    offset: offset,
                    limit: limit,
                    total: 30
                )
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()

        let requests = await recorder.requests
        #expect(requests == [PaginationRequest(query: "iPhone", offset: 0, limit: SearchViewModel.pageSize)])
        #expect(viewModel.results.count == 10)
        #expect(viewModel.totalResults == 30)
        #expect(viewModel.paginationState == .idle)
    }

    @Test
    func loadMoreAppendsNextPageAndAdvancesOffset() async {
        let recorder = PaginationRequestRecorder()
        let viewModel = SearchViewModel(
            repository: .pagedMock(search: { query, offset, limit in
                await recorder.record(query: query, offset: offset, limit: limit)
                let items = (offset ..< offset + limit).map { index in
                    TestFixtures.summary(id: "ITEM-\(index)")
                }
                return ProductSearchPage(items: items, offset: offset, limit: limit, total: 30)
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()
        await viewModel.loadMoreIfNeeded()

        let requests = await recorder.requests
        #expect(requests == [
            PaginationRequest(query: "iPhone", offset: 0, limit: SearchViewModel.pageSize),
            PaginationRequest(query: "iPhone", offset: SearchViewModel.pageSize, limit: SearchViewModel.pageSize)
        ])
        #expect(viewModel.results.count == 20)
        #expect(viewModel.results.first?.id == "ITEM-0")
        #expect(viewModel.results.last?.id == "ITEM-19")
        #expect(viewModel.paginationState == .idle)
    }

    @Test
    func loadMoreBecomesExhaustedWhenBackendReportsEnd() async {
        let viewModel = SearchViewModel(
            repository: .pagedMock(search: { _, offset, limit in
                let pageItems = (offset ..< offset + min(limit, max(0, 15 - offset))).map { index in
                    TestFixtures.summary(id: "ITEM-\(index)")
                }
                return ProductSearchPage(items: pageItems, offset: offset, limit: limit, total: 15)
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()
        await viewModel.loadMoreIfNeeded()

        #expect(viewModel.results.count == 15)
        #expect(viewModel.paginationState == .exhausted)
    }

    @Test
    func loadMoreDoesNothingWhenNotInLoadedState() async {
        let recorder = PaginationRequestRecorder()
        let viewModel = SearchViewModel(
            repository: .pagedMock(search: { query, offset, limit in
                await recorder.record(query: query, offset: offset, limit: limit)
                return ProductSearchPage(items: [], offset: offset, limit: limit, total: 0)
            }),
            configuration: .preview
        )

        await viewModel.loadMoreIfNeeded()

        #expect(await recorder.requests.isEmpty)
        #expect(viewModel.paginationState == .idle)
    }

    @Test
    func loadMoreIsGatedWhileAnotherPageIsInFlight() async throws {
        let recorder = PaginationRequestRecorder()
        let viewModel = SearchViewModel(
            repository: .pagedMock(search: { query, offset, limit in
                await recorder.record(query: query, offset: offset, limit: limit)
                if offset > 0 {
                    try await Task.sleep(for: .milliseconds(100))
                }
                let items = (offset ..< offset + limit).map { index in
                    TestFixtures.summary(id: "ITEM-\(index)")
                }
                return ProductSearchPage(items: items, offset: offset, limit: limit, total: 100)
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()

        let firstLoadMore = Task { await viewModel.loadMoreIfNeeded() }
        let secondLoadMore = Task { await viewModel.loadMoreIfNeeded() }

        await firstLoadMore.value
        await secondLoadMore.value

        let requests = await recorder.requests
        // First call = initial search at offset 0. Second = the one loadMore that passed the gate.
        #expect(requests.count == 2)
        #expect(requests[1].offset == SearchViewModel.pageSize)
        #expect(viewModel.results.count == 2 * SearchViewModel.pageSize)
    }

    @Test
    func loadMoreSurfacesErrorAndRetrySucceeds() async {
        let attempts = LoadMoreAttemptCounter()
        let viewModel = SearchViewModel(
            repository: .pagedMock(search: { _, offset, limit in
                if offset == 0 {
                    let items = (0 ..< limit).map { index in TestFixtures.summary(id: "ITEM-\(index)") }
                    return ProductSearchPage(items: items, offset: 0, limit: limit, total: 30)
                }

                let attempt = await attempts.incrementAndRead()
                if attempt == 1 {
                    throw AppError.forbidden
                }

                let items = (offset ..< offset + limit).map { index in
                    TestFixtures.summary(id: "ITEM-\(index)")
                }
                return ProductSearchPage(items: items, offset: offset, limit: limit, total: 30)
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()
        await viewModel.loadMoreIfNeeded()

        #expect(viewModel.paginationState == .failedToLoadMore(AppError.forbidden))
        #expect(viewModel.results.count == SearchViewModel.pageSize)

        await viewModel.retryLoadMore()

        #expect(viewModel.paginationState == .idle)
        #expect(viewModel.results.count == 2 * SearchViewModel.pageSize)
    }

    @Test
    func newSearchInvalidatesInFlightLoadMoreResponse() async throws {
        let viewModel = SearchViewModel(
            repository: .pagedMock(search: { query, offset, limit in
                if query == "iPhone", offset == 0 {
                    let items = (0 ..< limit).map { index in TestFixtures.summary(id: "IP-\(index)") }
                    return ProductSearchPage(items: items, offset: 0, limit: limit, total: 30)
                }

                if query == "iPhone", offset > 0 {
                    try await Task.sleep(for: .milliseconds(200))
                    let items = (offset ..< offset + limit).map { index in
                        TestFixtures.summary(id: "IP-\(index)")
                    }
                    return ProductSearchPage(items: items, offset: offset, limit: limit, total: 30)
                }

                let items = (offset ..< offset + limit).map { index in
                    TestFixtures.summary(id: "SONY-\(index)")
                }
                return ProductSearchPage(items: items, offset: offset, limit: limit, total: 5)
            }),
            configuration: .preview
        )

        viewModel.query = "iPhone"
        await viewModel.search()

        let loadMoreTask = Task { await viewModel.loadMoreIfNeeded() }
        try await Task.sleep(for: .milliseconds(20))

        viewModel.query = "Sony"
        await viewModel.search()
        await loadMoreTask.value

        // The results and state must reflect the Sony search, not the discarded iPhone load-more.
        #expect(viewModel.lastSubmittedQuery == "Sony")
        #expect(viewModel.results.allSatisfy { $0.id.hasPrefix("SONY-") })
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
    static let summary = summary(id: "ITEM-1")

    /// Builds a reusable product fixture with a caller-specified identifier.
    static func summary(id: String) -> ProductSummary {
        ProductSummary(
            id: id,
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
}

/// Parameters captured from a single paginated repository invocation.
private struct PaginationRequest: Equatable {
    let query: String
    let offset: Int
    let limit: Int
}

/// Records the offset/limit/query sequence used by pagination tests.
private actor PaginationRequestRecorder {
    private(set) var requests: [PaginationRequest] = []

    func record(query: String, offset: Int, limit: Int) {
        requests.append(PaginationRequest(query: query, offset: offset, limit: limit))
    }
}

/// Counts load-more attempts so a failing fixture can succeed on retry.
private actor LoadMoreAttemptCounter {
    private var count = 0

    func incrementAndRead() -> Int {
        count += 1
        return count
    }
}

private extension ProductRepository {
    /// Adapts a classic `(query) -> [ProductSummary]` closure into the paged repository shape.
    /// Keeps existing tests terse while the view model drives pagination via offset/limit.
    static func mock(
        search: @escaping (String) async throws -> [ProductSummary] = { _ in [] },
        detail: @escaping (String) async throws -> ProductDetail = { _ in
            throw AppError.unknown("No detail stub was provided.")
        }
    ) -> ProductRepository {
        ProductRepository(
            search: { query, offset, limit in
                let allItems = try await search(query)
                let clampedOffset = max(0, min(offset, allItems.count))
                let upperBound = min(clampedOffset + max(0, limit), allItems.count)
                let pageItems = Array(allItems[clampedOffset ..< upperBound])
                return ProductSearchPage(
                    items: pageItems,
                    offset: clampedOffset,
                    limit: limit,
                    total: allItems.count
                )
            },
            detail: detail
        )
    }

    /// Exposes the full paged closure for tests that need to assert offset/limit values.
    static func pagedMock(
        search: @escaping (_ query: String, _ offset: Int, _ limit: Int) async throws -> ProductSearchPage,
        detail: @escaping (String) async throws -> ProductDetail = { _ in
            throw AppError.unknown("No detail stub was provided.")
        }
    ) -> ProductRepository {
        ProductRepository(search: search, detail: detail)
    }
}
