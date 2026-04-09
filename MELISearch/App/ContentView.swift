import SwiftUI

/// The root navigation host that injects shared dependencies into the search and detail flows.
struct ContentView: View {
    /// Root tabs available from the app's main surface.
    private enum RootTab {
        case search
        case favorites
    }

    /// The startup configuration used as the basis for runtime demo/live overrides.
    private let baseConfiguration: AppConfiguration

    /// The active dependency container for the currently selected data source.
    @State private var activeContainer: AppContainer
    /// The shared OAuth session that manages live Mercado Libre authorization.
    @State private var authenticationSession: MELIAuthenticationSession
    /// The search view model so it survives SwiftUI view refreshes.
    @State private var viewModel: SearchViewModel
    /// The  connectivity monitor shared with the search screen.
    @State private var connectivityMonitor: ConnectivityMonitor
    /// Favorites persisted across app launches and shared by all tabs.
    @State private var favoritesStore: FavoritesStore
    /// Resets the navigation tree when switching between demo and live.
    @State private var navigationIdentity = UUID()
    /// Keeps the currently selected root tab stable across refreshes.
    @State private var selectedTab = RootTab.search

    /// Builds the root screen graph with dependencies sourced from the app container.
    /// - Parameters:
    ///   - container: Shared dependencies assembled by the app entry point.
    init(container: AppContainer) {
        baseConfiguration = container.configuration
        _activeContainer = State(initialValue: container)
        _authenticationSession = State(initialValue: container.authenticationSession)
        _viewModel = State(
            initialValue: SearchViewModel(
                repository: container.productRepository,
                configuration: container.configuration
            )
        )
        _connectivityMonitor = State(initialValue: container.connectivityMonitor)
        _favoritesStore = State(initialValue: container.favoritesStore)
    }

    /// Renders the root navigation stack and coordinates OAuth callback completion from incoming URLs.
    var body: some View {
        TabView(selection: $selectedTab) {
            searchTab
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(RootTab.search)

            favoritesTab
                .tabItem {
                    Label("Favorites", systemImage: favoritesStore.favorites.isEmpty ? "heart" : "heart.fill")
                }
                .tag(RootTab.favorites)
        }
        .task {
            await authenticationSession.prepareIfNeeded()
        }
        .onOpenURL { url in
            Task {
                _ = await authenticationSession.completeAuthorizationIfPossible(from: url)
            }
        }
    }
}

private extension ContentView {
    /// Search root hosted inside its own navigation stack.
    var searchTab: some View {
        NavigationStack {
            SearchScreen(
                viewModel: viewModel,
                connectivityMonitor: connectivityMonitor,
                authenticationSession: authenticationSession,
                onSelectDataSource: switchDataSource(to:)
            )
            .navigationDestination(for: ProductSummary.self, destination: detailScreen)
        }
        .id(navigationIdentity)
    }

    /// Favorites root hosted inside its own navigation stack.
    var favoritesTab: some View {
        NavigationStack {
            FavoritesScreen(favoritesStore: favoritesStore)
                .navigationDestination(for: ProductSummary.self, destination: detailScreen)
        }
        .id(navigationIdentity)
    }

    /// Shared detail destination used from both search results and favorites.
    /// - Parameter product: Product selected from either root tab.
    /// - Returns: Product detail screen backed by the active repository and favorites store.
    func detailScreen(for product: ProductSummary) -> some View {
        ProductDetailScreen(
            product: product,
            repository: activeContainer.productRepository,
            configuration: activeContainer.configuration,
            favoritesStore: favoritesStore
        )
    }

    /// Rebuilds the app container for the selected data source and resets UI state that depends on it.
    /// - Parameter dataSource: Runtime backend mode that should become active.
    func switchDataSource(to dataSource: AppConfiguration.DataSource) {
        guard activeContainer.configuration.dataSource != dataSource else {
            return
        }

        let updatedConfiguration = baseConfiguration.overriding(dataSource: dataSource)
        let updatedContainer = AppContainer.main(
            configuration: updatedConfiguration,
            favoritesStore: favoritesStore
        )

        activeContainer = updatedContainer
        authenticationSession = updatedContainer.authenticationSession
        viewModel = SearchViewModel(
            repository: updatedContainer.productRepository,
            configuration: updatedContainer.configuration
        )
        connectivityMonitor = updatedContainer.connectivityMonitor
        navigationIdentity = UUID()
    }
}

#Preview {
    ContentView(container: .main(configuration: .preview))
}
