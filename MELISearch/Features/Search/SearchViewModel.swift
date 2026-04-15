import Foundation
import Observation
import OSLog

@MainActor
@Observable
/// State holder for the product search flow.
final class SearchViewModel {
    /// View state rendered by the search screen.
    enum State: Equatable {
        /// No query has been submitted yet.
        case idle
        /// A repository search request is in flight.
        case loading
        /// The latest search returned one or more products.
        case loaded
        /// The latest search completed successfully but returned no products.
        case empty
        /// The latest search failed and produced a domain error.
        case failed(AppError)
    }

    /// Pagination lifecycle for the currently loaded results.
    enum PaginationState: Equatable {
        /// No additional work is in flight and more pages may still be available.
        case idle
        /// An additional page request is in flight.
        case loadingMore
        /// Every page has been consumed for the current query.
        case exhausted
        /// The latest load-more attempt failed and can be retried.
        case failedToLoadMore(AppError)
    }

    /// Page size used for every search request and pagination fetch.
    static let pageSize = 10

    /// Current user-entered query bound to the search field.
    var query: String {
        didSet {
            guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            resetToIdle()
        }
    }
    /// Latest product summaries returned by the repository.
    private(set) var results: [ProductSummary]
    /// Current rendering state of the search screen.
    private(set) var state: State
    /// Pagination state derived from the latest page response.
    private(set) var paginationState: PaginationState
    /// Last non-empty query submitted to the repository.
    private(set) var lastSubmittedQuery: String
    /// Timestamp of the most recent successful search response shown by the UI.
    private(set) var lastUpdatedAt: Date?
    /// Total number of items reported by the backend for the active query when available.
    private(set) var totalResults: Int?

    /// Runtime configuration exposed to the UI for environment messaging.
    let configuration: AppConfiguration

    /// Repository that executes search and detail requests.
    @ObservationIgnored private let repository: ProductRepository
    /// Date provider injected for deterministic tests and last-updated messaging.
    @ObservationIgnored private let dateProvider: () -> Date
    /// Monotonic counter used to invalidate stale in-flight search responses.
    @ObservationIgnored private var searchGeneration = 0
    /// Zero-based offset of the next page to request for the active query.
    @ObservationIgnored private var nextOffset = 0

    /// Creates the search state holder with an injected repository and initial query.
    /// - Parameters:
    ///   - repository: Repository that resolves search and detail requests.
    ///   - configuration: Runtime settings exposed to the UI.
    ///   - initialQuery: Initial search text, mainly used by previews or tests.
    ///   - dateProvider: Clock dependency used to stamp the last successful refresh.
    init(
        repository: ProductRepository,
        configuration: AppConfiguration,
        initialQuery: String = "",
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.configuration = configuration
        query = initialQuery
        results = []
        state = .idle
        paginationState = .idle
        lastSubmittedQuery = ""
        lastUpdatedAt = nil
        totalResults = nil
    }

    /// Indicates whether the search screen should show a loading state.
    var isLoading: Bool {
        if case .loading = state {
            return true
        }

        return false
    }

    /// Normalizes the query, executes the first-page search, and updates the screen state.
    func search() async {
        // Persist the trimmed query so the text field and request always stay aligned.
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        query = normalizedQuery

        guard !normalizedQuery.isEmpty else {
            resetToIdle()
            return
        }

        searchGeneration &+= 1
        let currentSearchGeneration = searchGeneration
        state = .loading
        paginationState = .idle
        nextOffset = 0
        totalResults = nil
        lastSubmittedQuery = normalizedQuery

        do {
            let page = try await repository.searchProducts(
                matching: normalizedQuery,
                offset: 0,
                limit: Self.pageSize
            )
            guard currentSearchGeneration == searchGeneration else {
                return
            }

            results = page.items
            totalResults = page.total
            nextOffset = page.offset + page.items.count
            lastUpdatedAt = dateProvider()
            state = page.items.isEmpty ? .empty : .loaded
            paginationState = page.hasMorePages ? .idle : .exhausted
        } catch {
            guard currentSearchGeneration == searchGeneration else {
                return
            }

            let appError = AppError.from(error)
            results = []
            totalResults = nil
            nextOffset = 0
            state = .failed(appError)
            paginationState = .idle
            AppLogger.ui.error("Search failed: \(appError.developerDescription)")
        }
    }

    /// Loads the next page when the user nears the bottom of the result list.
    /// The call is gated so repeated scroll events during a fetch do not duplicate requests.
    func loadMoreIfNeeded() async {
        // Only paginate while a successful first page is on screen.
        guard case .loaded = state else {
            return
        }

        // Never launch a second request while one is already in flight or we reached the end.
        switch paginationState {
        case .loadingMore, .exhausted, .failedToLoadMore:
            return
        case .idle:
            break
        }

        guard !lastSubmittedQuery.isEmpty else {
            return
        }

        let currentSearchGeneration = searchGeneration
        let requestedOffset = nextOffset
        paginationState = .loadingMore

        do {
            let page = try await repository.searchProducts(
                matching: lastSubmittedQuery,
                offset: requestedOffset,
                limit: Self.pageSize
            )
            guard currentSearchGeneration == searchGeneration else {
                return
            }

            // De-dupe against results already on screen in case the backend overlaps pages.
            let existingIDs = Set(results.map(\.id))
            let newItems = page.items.filter { !existingIDs.contains($0.id) }

            results.append(contentsOf: newItems)
            totalResults = page.total ?? totalResults
            nextOffset = page.offset + page.items.count
            lastUpdatedAt = dateProvider()
            paginationState = page.hasMorePages ? .idle : .exhausted
        } catch {
            guard currentSearchGeneration == searchGeneration else {
                return
            }

            let appError = AppError.from(error)
            paginationState = .failedToLoadMore(appError)
            AppLogger.ui.error("Load more failed: \(appError.developerDescription)")
        }
    }

    /// Retries the most recent failed load-more attempt. No-op when the last call succeeded.
    func retryLoadMore() async {
        guard case .failedToLoadMore = paginationState else {
            return
        }

        paginationState = .idle
        await loadMoreIfNeeded()
    }

    /// Replays the most recent successful submission for pull-to-refresh and retries.
    /// The view model restores the stored query before delegating back to `search()`.
    func repeatLastSearch() async {
        guard !lastSubmittedQuery.isEmpty else {
            return
        }

        query = lastSubmittedQuery
        await search()
    }

    /// Applies a preset suggestion and immediately triggers a search.
    /// - Parameter suggestion: Suggested query selected from the idle-state shortcuts.
    func applySuggestion(_ suggestion: String) async {
        query = suggestion
        await search()
    }

    /// Clears search-derived state and returns the screen to its initial idle presentation.
    private func resetToIdle() {
        searchGeneration &+= 1
        results = []
        state = .idle
        paginationState = .idle
        lastSubmittedQuery = ""
        lastUpdatedAt = nil
        totalResults = nil
        nextOffset = 0
    }
}
