import Foundation
import Testing
@testable import MELISearch

@Suite(.serialized)
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
    func loadIfNeededDoesNotFetchTwiceAfterSuccess() async {
        let callCounter = DetailCallCounter()
        let repository = ProductRepository(
            search: { _, offset, limit in
                ProductSearchPage(items: [], offset: offset, limit: limit, total: 0)
            },
            detail: { _ in
                await callCounter.increment()
                return DetailFixtures.detail
            }
        )
        let viewModel = ProductDetailViewModel(
            product: DetailFixtures.summary,
            repository: repository,
            configuration: .preview
        )

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(await callCounter.count == 1)
        #expect(viewModel.detail == DetailFixtures.detail)
    }

    @Test
    func reloadFetchesFreshDetailAfterSuccess() async {
        let sequence = DetailSequence(
            first: DetailFixtures.detail,
            second: DetailFixtures.reloadedDetail
        )
        let repository = ProductRepository(
            search: { _, offset, limit in
                ProductSearchPage(items: [], offset: offset, limit: limit, total: 0)
            },
            detail: { id in
                #expect(id == DetailFixtures.summary.id)
                return await sequence.next()
            }
        )
        let viewModel = ProductDetailViewModel(
            product: DetailFixtures.summary,
            repository: repository,
            configuration: .preview
        )

        await viewModel.loadIfNeeded()
        let firstLoadedTitle = viewModel.displayedTitle

        await viewModel.reload()

        #expect(firstLoadedTitle == DetailFixtures.detail.title)
        #expect(viewModel.displayedTitle == DetailFixtures.reloadedDetail.title)
        #expect(viewModel.detail == DetailFixtures.reloadedDetail)
    }

    @Test
    func summaryValuesBackTheUIBeforeDetailLoads() {
        let viewModel = ProductDetailViewModel(
            product: DetailFixtures.summary,
            repository: .detailMock(DetailFixtures.detail),
            configuration: .preview
        )

        #expect(viewModel.displayedTitle == DetailFixtures.summary.title)
        #expect(viewModel.displayedSubtitle == DetailFixtures.summary.subtitle)
        #expect(viewModel.displayedPrice == DetailFixtures.summary.price)
        #expect(viewModel.currencyCode == DetailFixtures.summary.currencyCode)
        #expect(viewModel.imageURLs == [DetailFixtures.summaryThumbnailURL])
        #expect(viewModel.shipping == DetailFixtures.summary.shipping)
        #expect(viewModel.displayedAttributes == DetailFixtures.summary.attributes)
        #expect(viewModel.permalinkURL == DetailFixtures.summary.permalinkURL)
        #expect(viewModel.condition == DetailFixtures.summary.condition)
        #expect(viewModel.availableQuantity == DetailFixtures.summary.availableQuantity)
        #expect(viewModel.soldQuantity == DetailFixtures.summary.soldQuantity)
        #expect(viewModel.warranty == nil)
        #expect(viewModel.descriptionText == nil)
    }

    @Test
    func loadedDetailOverridesSummaryDerivedValues() async {
        let viewModel = ProductDetailViewModel(
            product: DetailFixtures.summary,
            repository: .detailMock(DetailFixtures.detail),
            configuration: .preview
        )

        await viewModel.loadIfNeeded()

        #expect(viewModel.displayedTitle == DetailFixtures.detail.title)
        #expect(viewModel.displayedSubtitle == DetailFixtures.detail.subtitle)
        #expect(viewModel.displayedPrice == DetailFixtures.detail.price)
        #expect(viewModel.currencyCode == DetailFixtures.detail.currencyCode)
        #expect(viewModel.imageURLs == [DetailFixtures.summaryThumbnailURL])
        #expect(viewModel.shipping == DetailFixtures.detail.shipping)
        #expect(viewModel.displayedAttributes == DetailFixtures.detail.attributes)
        #expect(viewModel.permalinkURL == DetailFixtures.detail.permalinkURL)
        #expect(viewModel.condition == DetailFixtures.detail.condition)
        #expect(viewModel.availableQuantity == DetailFixtures.detail.availableQuantity)
        #expect(viewModel.soldQuantity == DetailFixtures.detail.soldQuantity)
        #expect(viewModel.warranty == DetailFixtures.detail.warranty)
        #expect(viewModel.descriptionText == DetailFixtures.detail.description)
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

    @Test
    func failedReloadKeepsPreviouslyLoadedDetailVisible() async {
        let callCounter = DetailCallCounter()
        let repository = ProductRepository(
            search: { _, offset, limit in
                ProductSearchPage(items: [], offset: offset, limit: limit, total: 0)
            },
            detail: { _ in
                let currentCall = await callCounter.incrementAndReturn()

                if currentCall == 1 {
                    return DetailFixtures.detail
                }

                throw AppError.transport(.cannotConnectToHost)
            }
        )
        let viewModel = ProductDetailViewModel(
            product: DetailFixtures.summary,
            repository: repository,
            configuration: .preview
        )

        await viewModel.loadIfNeeded()
        await viewModel.reload()

        #expect(viewModel.state == .failed(.transport(.cannotConnectToHost)))
        #expect(viewModel.detail == DetailFixtures.detail)
        #expect(viewModel.displayedTitle == DetailFixtures.detail.title)
        #expect(viewModel.imageURLs == [DetailFixtures.summaryThumbnailURL])
    }
}

private enum DetailFixtures {
    static let summaryThumbnailURL = URL(string: "https://example.com/thumb.jpg")!

    static let summary = ProductSummary(
        id: "ITEM-2",
        title: "Sony WH-1000XM5",
        subtitle: "Headphones",
        price: 20,
        currencyCode: "ARS",
        thumbnailURL: summaryThumbnailURL,
        permalinkURL: URL(string: "https://example.com/summary"),
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

    static let reloadedDetail = ProductDetail(
        id: "ITEM-2",
        title: "Sony WH-1000XM5 Updated Detail",
        subtitle: "Reloaded detail",
        price: 30,
        currencyCode: "USD",
        imageURLs: [URL(string: "https://example.com/reloaded.jpg")!],
        permalinkURL: URL(string: "https://example.com/reloaded"),
        condition: "refurbished",
        availableQuantity: 4,
        soldQuantity: 10,
        warranty: "24 months",
        attributes: [ProductAttribute(id: "COLOR", name: "Color", value: "Silver")],
        shipping: ShippingInfo(isFreeShipping: false, isStorePickupAvailable: true),
        description: "Reloaded detail fixture"
    )
}

private actor DetailCallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }

    func incrementAndReturn() -> Int {
        count += 1
        return count
    }
}

private actor DetailSequence {
    private let first: ProductDetail
    private let second: ProductDetail
    private var callCount = 0

    init(first: ProductDetail, second: ProductDetail) {
        self.first = first
        self.second = second
    }

    func next() -> ProductDetail {
        callCount += 1
        return callCount == 1 ? first : second
    }
}

private extension ProductRepository {
    static func detailMock(_ detail: ProductDetail) -> ProductRepository {
        ProductRepository(
            search: { _, offset, limit in
                ProductSearchPage(items: [], offset: offset, limit: limit, total: 0)
            },
            detail: { _ in detail }
        )
    }

    static func failingDetailMock(_ error: AppError) -> ProductRepository {
        ProductRepository(
            search: { _, offset, limit in
                ProductSearchPage(items: [], offset: offset, limit: limit, total: 0)
            },
            detail: { _ in throw error }
        )
    }
}
