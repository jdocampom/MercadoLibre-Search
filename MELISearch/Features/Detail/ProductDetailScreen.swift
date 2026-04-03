import SwiftUI

/// Product detail experience that expands a search result into richer product information.
struct ProductDetailScreen: View {
    @State private var selectedImageIndex = 0
    @State private var viewModel: ProductDetailViewModel

    private let factColumns = [GridItem(.flexible()), GridItem(.flexible())]

    /// Creates the detail screen with the dependencies required to fetch full item data.
    /// - Parameters:
    ///   - product: Summary payload selected from the search results.
    ///   - repository: Repository used to fetch full product details.
    ///   - configuration: Runtime settings for the current app session.
    init(
        product: ProductSummary,
        repository: ProductRepository,
        configuration: AppConfiguration
    ) {
        _viewModel = State(
            initialValue: ProductDetailViewModel(
                product: product,
                repository: repository,
                configuration: configuration
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                gallerySection
                summaryCard
                shippingCard

                if !viewModel.displayedAttributes.isEmpty {
                    attributesSection
                }

                if let descriptionText = viewModel.descriptionText {
                    descriptionSection(descriptionText)
                }

                if let error = currentError {
                    errorCard(error)
                }

                if let permalinkURL = viewModel.permalinkURL {
                    Link(destination: permalinkURL) {
                        Label("Open on Mercado Libre", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle(viewModel.displayedTitle)
        .modifier(ProductDetailNavigationTitleStyle())
        .refreshable {
            await viewModel.reload()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}

private extension ProductDetailScreen {
    var gallerySection: some View {
        Group {
            if viewModel.imageURLs.count > 1 {
                #if os(macOS)
                macOSGallery
                #else
                pagedGallery
                #endif
            } else if let firstImageURL = viewModel.imageURLs.first {
                remoteImage(firstImageURL)
                    .frame(height: 320)
            } else {
                placeholderImage
                    .frame(height: 320)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    #if !os(macOS)
    var pagedGallery: some View {
        TabView(selection: $selectedImageIndex) {
            ForEach(Array(viewModel.imageURLs.enumerated()), id: \.offset) { index, imageURL in
                remoteImage(imageURL)
                    .tag(index)
            }
        }
        .frame(height: 320)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }
    #endif

    var macOSGallery: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(Array(viewModel.imageURLs.enumerated()), id: \.offset) { _, imageURL in
                    remoteImage(imageURL)
                        .frame(width: 320, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(height: 320)
    }

    var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let subtitle = viewModel.displayedSubtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.displayedPrice.formatted(.currency(code: viewModel.currencyCode)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            if case .loading = viewModel.state {
                ProgressView("Loading product details…")
            }

            LazyVGrid(columns: factColumns, spacing: 12) {
                if let condition = viewModel.condition {
                    FactCard(title: "Condition", value: condition.capitalized)
                }

                if let availableQuantity = viewModel.availableQuantity {
                    FactCard(title: "Available", value: "\(availableQuantity)")
                }

                if let soldQuantity = viewModel.soldQuantity {
                    FactCard(title: "Sold", value: "\(soldQuantity)")
                }

                if let warranty = viewModel.warranty {
                    FactCard(title: "Warranty", value: warranty)
                }
            }
        }
        .padding(22)
        .background(sectionBackground)
    }

    var shippingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shipping")
                .font(.headline)

            FactCard(
                title: "Free shipping",
                value: viewModel.shipping.isFreeShipping ? "Available" : "Not available"
            )

            FactCard(
                title: "Store pickup",
                value: viewModel.shipping.isStorePickupAvailable ? "Available" : "Not available"
            )
        }
        .padding(22)
        .background(sectionBackground)
    }

    var attributesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Attributes")
                .font(.headline)

            LazyVGrid(columns: factColumns, spacing: 12) {
                ForEach(viewModel.displayedAttributes) { attribute in
                    FactCard(title: attribute.name, value: attribute.value)
                }
            }
        }
        .padding(22)
        .background(sectionBackground)
    }

    /// Builds the description section when the product exposes longer-form copy.
    /// - Parameter descriptionText: Seller-provided product description.
    /// - Returns: A styled section containing the product description.
    func descriptionSection(_ descriptionText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)

            Text(descriptionText)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(sectionBackground)
    }

    /// Builds the detail failure panel shown after a rejected or failed request.
    /// - Parameter error: Domain error produced by the detail request.
    /// - Returns: A retryable error card for the detail screen.
    func errorCard(_ error: AppError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Detail request failed", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Color(red: 0.67, green: 0.19, blue: 0.13))

            Text(error.localizedDescription)
                .foregroundStyle(.secondary)

            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Retry") {
                Task {
                    await viewModel.reload()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
        .background(sectionBackground)
    }

    /// Loads a remote image and falls back to the placeholder for empty or failed states.
    /// - Parameter url: Remote image URL to render.
    /// - Returns: An async image view backed by the provided URL.
    func remoteImage(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                placeholderImage
            }
        }
    }

    var placeholderImage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.91, blue: 0.74),
                    Color(red: 0.83, green: 0.90, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "shippingbox.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)
        }
    }

    var currentError: AppError? {
        guard case let .failed(error) = viewModel.state else {
            return nil
        }

        return error
    }

    var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.97, blue: 0.94),
                Color(red: 0.92, green: 0.96, blue: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.86))
    }
}

#if os(macOS)
/// Leaves the default macOS navigation title behavior untouched.
private struct ProductDetailNavigationTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
#else
/// Applies the iOS navigation title and toolbar styling for the detail screen.
private struct ProductDetailNavigationTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .modifier(AppNavigationBarStyle())
    }
}
#endif

/// Small reusable card for product facts and attribute values.
private struct FactCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
