import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ProductDetailViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(AppError)
    }

    let product: ProductSummary
    let configuration: AppConfiguration

    private(set) var state: State
    private(set) var detail: ProductDetail?

    @ObservationIgnored private let repository: ProductRepository

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

    func loadIfNeeded() async {
        guard case .idle = state else {
            return
        }

        await load()
    }

    func reload() async {
        await load()
    }

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
