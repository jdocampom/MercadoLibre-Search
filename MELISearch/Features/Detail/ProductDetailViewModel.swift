import Foundation
import Observation
import OSLog

@MainActor
@Observable
/// State holder that resolves and exposes product detail information for the detail screen.
final class ProductDetailViewModel {
    /// View state rendered by the detail screen.
    enum State: Equatable {
        /// Detail loading has not started yet.
        case idle
        /// The secondary detail request is currently in flight.
        case loading
        /// The secondary detail request completed successfully.
        case loaded
        /// The secondary detail request failed and produced a domain error.
        case failed(AppError)
    }

    /// Summary payload passed from the search screen during navigation.
    let product: ProductSummary
    /// Runtime configuration exposed to the UI when needed.
    let configuration: AppConfiguration

    /// Current loading state of the detail request.
    private(set) var state: State
    /// Full product detail returned by the repository once available.
    private(set) var detail: ProductDetail?

    /// Repository used to resolve the secondary detail request.
    @ObservationIgnored private let repository: ProductRepository

    /// Creates the detail state holder with the selected product and repository.
    /// - Parameters:
    ///   - product: Summary payload selected from the search results.
    ///   - repository: Repository used to fetch full product details.
    ///   - configuration: Runtime settings exposed to the UI layer.
    init(
        product: ProductSummary,
        repository: ProductRepository,
        configuration: AppConfiguration
    ) {
        self.product = product
        self.repository = repository
        self.configuration = configuration
        state = .idle
        detail = nil
    }

    /// Title rendered by the detail screen, falling back to the summary model before detail loads.
    var displayedTitle: String {
        detail?.title ?? product.title
    }

    /// Subtitle rendered by the detail screen when available.
    var displayedSubtitle: String? {
        detail?.subtitle ?? product.subtitle
    }

    /// Price rendered by the detail screen, preserving the summary value while loading.
    var displayedPrice: Double {
        detail?.price ?? product.price
    }

    /// Currency code associated with `displayedPrice`.
    var currencyCode: String {
        detail?.currencyCode ?? product.currencyCode
    }

    /// Gallery or thumbnail URLs available for the current product presentation.
    var imageURLs: [URL] {
        if let detail, !detail.imageURLs.isEmpty {
            return detail.imageURLs
        }

        if let thumbnailURL = product.thumbnailURL {
            return [thumbnailURL]
        }

        return []
    }

    /// Shipping information shown in the detail screen.
    var shipping: ShippingInfo {
        detail?.shipping ?? product.shipping
    }

    /// Attributes rendered by the detail fact grid.
    var displayedAttributes: [ProductAttribute] {
        detail?.attributes ?? product.attributes
    }

    /// External Mercado Libre URL for the current product when available.
    var permalinkURL: URL? {
        detail?.permalinkURL ?? product.permalinkURL
    }

    /// Product condition shown in the summary fact grid.
    var condition: String? {
        detail?.condition ?? product.condition
    }

    /// Available stock shown in the summary fact grid.
    var availableQuantity: Int? {
        detail?.availableQuantity ?? product.availableQuantity
    }

    /// Sold quantity shown in the summary fact grid.
    var soldQuantity: Int? {
        detail?.soldQuantity ?? product.soldQuantity
    }

    /// Warranty string surfaced by the detail payload when available.
    var warranty: String? {
        detail?.warranty
    }

    /// Long-form description surfaced by the detail payload when available.
    var descriptionText: String? {
        detail?.description
    }

    /// Avoids duplicate loading work once the first request has already started.
    func loadIfNeeded() async {
        guard case .idle = state else {
            return
        }

        await load()
    }

    /// Forces a new detail request, usually from pull-to-refresh or retry UI.
    func reload() async {
        await load()
    }

    /// Resolves the detail payload and translates failures into view state.
    private func load() async {
        state = .loading

        do {
            let fetchedDetail = try await repository.fetchProductDetail(id: product.id)
            detail = fetchedDetail
            state = .loaded
        } catch {
            let appError = AppError.from(error)
            state = .failed(appError)
            AppLogger.ui.error("Detail failed: \(appError.developerDescription)")
        }
    }
}
