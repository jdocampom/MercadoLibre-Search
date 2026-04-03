import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class SearchViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(AppError)
    }

    var query: String
    private(set) var results: [ProductSummary]
    private(set) var state: State
    private(set) var lastSubmittedQuery: String

    let configuration: AppConfiguration

    @ObservationIgnored private let repository: ProductRepository

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

    func search() async {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        query = normalizedQuery

        guard !normalizedQuery.isEmpty else {
            results = []
            state = .idle
            return
        }

        state = .loading
        lastSubmittedQuery = normalizedQuery

        do {
            let fetchedProducts = try await repository.searchProducts(matching: normalizedQuery)
            results = fetchedProducts
            state = fetchedProducts.isEmpty ? .empty : .loaded
        } catch {
            let appError = AppError.from(error)
            results = []
            state = .failed(appError)
            AppLogger.ui.error("Search failed: \(appError.developerDescription)")
        }
    }

    func repeatLastSearch() async {
        guard !lastSubmittedQuery.isEmpty else {
            return
        }

        query = lastSubmittedQuery
        await search()
    }

    func applySuggestion(_ suggestion: String) async {
        query = suggestion
        await search()
    }
}
