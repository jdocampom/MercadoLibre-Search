import Observation
import SwiftUI

struct SearchScreen: View {
    @Bindable var viewModel: SearchViewModel

    private let suggestions = ["iPhone", "Sony", "Kindle", "Garmin", "Speaker"]
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard

                if viewModel.configuration.isUsingDemoData {
                    environmentBanner
                }

                content
            }
            .padding(20)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Mercado Libre Search")
        .modifier(SearchNavigationTitleStyle())
        .refreshable {
            await viewModel.repeatLastSearch()
        }
        .safeAreaInset(edge: searchBarEdge, spacing: 0) {
            searchBarContainer
        }
    }
}

private extension SearchScreen {
    var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search products with a resilient MVVM flow.")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text("The app preserves search state, surfaces errors clearly and navigates into a product detail flow ready for live Mercado Libre integration.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(viewModel.configuration.environmentBadge, systemImage: "shippingbox.circle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.86, blue: 0.18),
                    Color(red: 0.91, green: 0.95, blue: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    var searchBarContainer: some View {
        searchBar
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }

    var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search a product", text: $viewModel.query)
                .modifier(SearchTextFieldPlatformStyle())
                .accessibilityIdentifier("searchTextField")
                .onSubmit {
                    Task {
                        await viewModel.search()
                    }
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button("Search") {
                Task {
                    await viewModel.search()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.16, green: 0.33, blue: 0.71))
            .accessibilityIdentifier("searchButton")
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    var searchBarEdge: VerticalEdge {
        #if os(macOS)
        .top
        #else
        .bottom
        #endif
    }

    var environmentBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color(red: 0.11, green: 0.39, blue: 0.79))

            VStack(alignment: .leading, spacing: 6) {
                Text("Running in demo mode")
                    .font(.headline)

                Text(viewModel.configuration.assistantNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
    }

    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .idle:
            idleState
        case .loading:
            loadingState
        case .empty:
            emptyState
        case let .failed(error):
            errorState(error)
        case .loaded:
            resultsState
        }
    }

    var idleState: some View {
        VStack(alignment: .leading, spacing: 16) {
            ContentUnavailableView {
                Label("Search the catalog", systemImage: "magnifyingglass.circle")
            } description: {
                Text("Start with one of the demo suggestions or type any product name.")
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        Task {
                            await viewModel.applySuggestion(suggestion)
                        }
                    } label: {
                        Text(suggestion)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(cardBackground)
    }

    var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("Searching “\(viewModel.lastSubmittedQuery)”")
                .font(.headline)

            Text("The request is in flight. Pull to refresh if you want to retry later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(cardBackground)
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label("No products found", systemImage: "shippingbox")
        } description: {
            Text("Try a broader query or use one of the suggestions from the home state.")
        }
    }

    func errorState(_ error: AppError) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label("Search failed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Try Again") {
                Task {
                    await viewModel.search()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
    }

    var resultsState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.results.count) Results")
                    .font(.headline)

                Text("Last query: \(viewModel.lastSubmittedQuery)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 16) {
                ForEach(viewModel.results) { product in
                    NavigationLink(value: product) {
                        ProductRowView(product: product)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("productRow_\(product.id)")
                }
            }
        }
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

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.82))
    }
}

#if os(macOS)
private struct SearchNavigationTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
#else
private struct SearchNavigationTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.large)
    }
}
#endif

private struct SearchTextFieldPlatformStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content
        #else
        content
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
        #endif
    }
}
