import Foundation
import Testing
@testable import MeLi_Lite

@MainActor
struct ProductDetailViewModelTests {
    @Test
    func loadIfNeededStoresDetail() async {
        let viewModel = ProductDetailViewModel(
            product: DetailFixtures.summary,
            repository: .detailMock(DetailFixtures.detail),
            configuration: .preview
        )

        await viewModel.loadIfNeeded()

        #expect(viewModel.state == .loaded)
        #expect(viewModel.detail == DetailFixtures.detail)
        #expect(viewModel.displayedTitle == DetailFixtures.detail.title)
    }

    @Test
    func failingLoadKeepsSummaryVisible() async {
        let viewModel = ProductDetailViewModel(
            product: DetailFixtures.summary,
            repository: .failingDetailMock(.transport(.notConnectedToInternet)),
            configuration: .preview
        )

        await viewModel.loadIfNeeded()

        #expect(viewModel.state == .failed(.transport(.notConnectedToInternet)))
        #expect(viewModel.displayedTitle == DetailFixtures.summary.title)
        #expect(viewModel.detail == nil)
    }
}

private enum DetailFixtures {
    static let summary = ProductSummary(
        id: "ITEM-2",
        title: "Sony WH-1000XM5",
        subtitle: "Headphones",
        price: 20,
        currencyCode: "ARS",
        thumbnailURL: nil,
        permalinkURL: nil,
        condition: "new",
        availableQuantity: 2,
        soldQuantity: 5,
        attributes: [ProductAttribute(id: "BRAND", name: "Brand", value: "Sony")],
        shipping: ShippingInfo(isFreeShipping: true, isStorePickupAvailable: false)
    )

    static let detail = ProductDetail(
        id: "ITEM-2",
        title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones",
        subtitle: "Detail",
        price: 25,
        currencyCode: "ARS",
        imageURLs: [],
        permalinkURL: URL(string: "https://example.com"),
        condition: "new",
        availableQuantity: 3,
        soldQuantity: 8,
        warranty: "12 months",
        attributes: [ProductAttribute(id: "COLOR", name: "Color", value: "Black")],
        shipping: ShippingInfo(isFreeShipping: true, isStorePickupAvailable: false),
        description: "Detail fixture"
    )
}

private extension ProductRepository {
    static func detailMock(_ detail: ProductDetail) -> ProductRepository {
        ProductRepository(
            search: { _ in [] },
            detail: { _ in detail }
        )
    }

    static func failingDetailMock(_ error: AppError) -> ProductRepository {
        ProductRepository(
            search: { _ in [] },
            detail: { _ in throw error }
        )
    }
}
