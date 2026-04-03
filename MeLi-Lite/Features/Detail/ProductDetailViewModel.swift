import Foundation
import Observation
import OSLog

@MainActor
@Observable
/// State holder that resolves and exposes product detail information for the detail screen.
final class ProductDetailViewModel {
    /// View state rendered by the detail screen.
    enum State: Equatable {
        case idle
        case loading
        case loaded
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

    var displayedTitle: String {
        detail?.title ?? product.title
    }

    var displayedSubtitle: String? {
        detail?.subtitle ?? product.subtitle
    }

    var displayedPrice: Double {
        detail?.price ?? product.price
    }

    var currencyCode: String {
        detail?.currencyCode ?? product.currencyCode
    }

    var imageURLs: [URL] {
        if let detail, !detail.imageURLs.isEmpty {
            return detail.imageURLs
        }

        if let thumbnailURL = product.thumbnailURL {
            return [thumbnailURL]
        }

        return []
    }

    var shipping: ShippingInfo {
        detail?.shipping ?? product.shipping
    }

    var displayedAttributes: [ProductAttribute] {
        detail?.attributes ?? product.attributes
    }

    var permalinkURL: URL? {
        detail?.permalinkURL ?? product.permalinkURL
    }

    var condition: String? {
        detail?.condition ?? product.condition
    }

    var availableQuantity: Int? {
        detail?.availableQuantity ?? product.availableQuantity
    }

    var soldQuantity: Int? {
        detail?.soldQuantity ?? product.soldQuantity
    }

    var warranty: String? {
        detail?.warranty
    }

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
