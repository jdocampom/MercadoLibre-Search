import Foundation
import Observation
import OSLog

@MainActor
@Observable
/// State holder for the product search flow.
final class SearchViewModel {
    /// View state rendered by the search screen.
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(AppError)
    }

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
    /// Last non-empty query submitted to the repository.
    private(set) var lastSubmittedQuery: String

    /// Runtime configuration exposed to the UI for environment messaging.
    let configuration: AppConfiguration

    @ObservationIgnored private let repository: ProductRepository
    @ObservationIgnored private var searchGeneration = 0

    /// Creates the search state holder with an injected repository and initial query.
    /// - Parameters:
    ///   - repository: Repository that resolves search and detail requests.
    ///   - configuration: Runtime settings exposed to the UI.
    ///   - initialQuery: Initial search text, mainly used by previews or tests.
    init(
        repository: ProductRepository,
        configuration: AppConfiguration,
        initialQuery: String = ""
    ) {
        self.repository = repository
        self.configuration = configuration
        query = initialQuery
        results = []
        state = .idle
        lastSubmittedQuery = ""
    }

    var isLoading: Bool {
        if case .loading = state {
            return true
        }

        return false
    }

    /// Normalizes the query, executes the search, and updates the screen state.
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
        lastSubmittedQuery = normalizedQuery

        do {
            let fetchedProducts = try await repository.searchProducts(matching: normalizedQuery)
            guard currentSearchGeneration == searchGeneration else {
                return
            }

            results = fetchedProducts
            state = fetchedProducts.isEmpty ? .empty : .loaded
        } catch {
            guard currentSearchGeneration == searchGeneration else {
                return
            }

            let appError = AppError.from(error)
            results = []
            state = .failed(appError)
            AppLogger.ui.error("Search failed: \(appError.developerDescription)")
        }
    }

    /// Replays the most recent successful submission for pull-to-refresh and retries.
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

    private func resetToIdle() {
        searchGeneration &+= 1
        results = []
        state = .idle
        lastSubmittedQuery = ""
    }
}
