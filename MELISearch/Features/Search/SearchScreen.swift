import Observation
import SwiftUI

/// Main search experience for browsing Mercado Libre products.
struct SearchScreen: View {
    /// Search flow state and result data rendered by the screen.
    @Bindable var viewModel: SearchViewModel
    /// Reachability state used to surface live-mode connectivity warnings.
    @Bindable var connectivityMonitor: ConnectivityMonitor
    /// OAuth session state used to guide live Mercado Libre authorization.
    @Bindable var authenticationSession: MELIAuthenticationSession
    /// Handles runtime switching between demo fixtures and the live API.
    /// - Parameter dataSource: Backend mode selected from the toolbar menu.
    let onSelectDataSource: (AppConfiguration.DataSource) -> Void
    /// Controls keyboard focus for the search text field.
    @FocusState private var isSearchFieldFocused: Bool
    /// Controls whether the OAuth setup sheet is currently visible.
    @State private var isOAuthSheetPresented = false

    /// Curated demo suggestions shown in the idle state.
    private let suggestions = ["iPhone", "Sony", "Kindle", "Garmin", "Speaker"]
    /// Adaptive grid used to lay out idle-state suggestion chips.
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    /// Builds the search experience including banners, result states, and the pinned search bar.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if shouldShowConnectivityBanner {
                    connectivityBanner
                }

                if viewModel.configuration.isUsingDemoData {
                    environmentBanner
                } else if authenticationSession.shouldShowAuthorizationBanner {
                    liveAuthorizationBanner
                }

                content
            }
            .padding(20)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("MELI Search")
        .modifier(SearchNavigationSubtitleStyle(subtitle: navigationSubtitle))
        .modifier(SearchNavigationTitleStyle())
        .toolbar {
            searchFocusToolbarItem
            dataSourceToolbarItem
        }
        .refreshable {
            await viewModel.repeatLastSearch()
        }
        .sheet(isPresented: $isOAuthSheetPresented) {
            OAuthSetupSheet(authenticationSession: authenticationSession)
        }
        .safeAreaInset(edge: searchBarEdge, spacing: 0) {
            searchBarContainer
        }
        .task {
            await authenticationSession.prepareIfNeeded()
            if authenticationSession.shouldPromptForAuthorization {
                isOAuthSheetPresented = true
            }
        }
    }
}

private extension SearchScreen {
    /// Banner displayed when live mode is active but network reachability is unavailable.
    var connectivityBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("No Internet Connection", systemImage: "wifi.slash")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text("Reconnect to continue searching Mercado Libre products and refreshing live results.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("Live requests unavailable", systemImage: "exclamationmark.triangle.fill")
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
                    Color(red: 0.99, green: 0.84, blue: 0.70),
                    Color(red: 0.99, green: 0.94, blue: 0.89)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .accessibilityIdentifier("connectivityBanner")
    }

    /// Wraps the search bar so it can be inset into the safe area with consistent padding.
    var searchBarContainer: some View {
        searchBar
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }

    /// Search field and submit controls pinned to the safe area edge.
    var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search a product", text: $viewModel.query)
                .modifier(SearchTextFieldPlatformStyle())
                .focused($isSearchFieldFocused)
                .accessibilityIdentifier("searchTextField")
                .onSubmit {
                    Task {
                        await viewModel.search()
                    }
                    isSearchFieldFocused = false
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
                isSearchFieldFocused = false
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .accessibilityIdentifier("searchButton")
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// Chooses whether the search bar is pinned to the top or bottom based on platform conventions.
    var searchBarEdge: VerticalEdge {
        #if os(macOS)
        .top
        #else
        .bottom
        #endif
    }

    @ToolbarContentBuilder
    /// Toolbar item that toggles focus for the search field.
    var searchFocusToolbarItem: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .primaryAction) {
            searchFocusButton
        }
        #else
        ToolbarItem(placement: .topBarTrailing) {
            searchFocusButton
        }
        #endif
    }

    /// Button used to focus or dismiss the search field.
    var searchFocusButton: some View {
        Button(action: toggleSearchFocus) {
            Image(systemName: isSearchFieldFocused ? "keyboard.chevron.compact.down" : "magnifyingglass")
        }
        .accessibilityIdentifier("searchFocusButton")
        .accessibilityLabel(isSearchFieldFocused ? "Dismiss search keyboard" : "Focus search field")
    }

    @ToolbarContentBuilder
    /// Toolbar item that exposes the runtime demo/live data-source menu.
    var dataSourceToolbarItem: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .automatic) {
            dataSourceMenu
        }
        #else
        ToolbarItem(placement: .topBarTrailing) {
            dataSourceMenu
        }
        #endif
    }

    /// Menu that switches the app container between demo fixtures and the live API.
    var dataSourceMenu: some View {
        Menu {
            Button {
                onSelectDataSource(.demo)
            } label: {
                Label("Use Demo Data", systemImage: viewModel.configuration.isUsingDemoData ? "checkmark" : "shippingbox")
            }
            .disabled(viewModel.configuration.isUsingDemoData)

            Button {
                onSelectDataSource(.live)
            } label: {
                Label("Use Live API", systemImage: viewModel.configuration.isUsingDemoData ? "antenna.radiowaves.left.and.right" : "checkmark")
            }
            .disabled(!viewModel.configuration.isUsingDemoData)
        } label: {
            Label(
                viewModel.configuration.isUsingDemoData ? "Demo" : "Live",
                systemImage: viewModel.configuration.isUsingDemoData ? "shippingbox" : "antenna.radiowaves.left.and.right"
            )
        }
        .accessibilityIdentifier("dataSourceMenu")
        .accessibilityLabel(viewModel.configuration.isUsingDemoData ? "Demo data menu" : "Live API menu")
    }

    /// Indicates whether the live connectivity warning banner should be visible.
    var shouldShowConnectivityBanner: Bool {
        !viewModel.configuration.isUsingDemoData && connectivityMonitor.status == .disconnected
    }

    /// Subtitle used to show the last successful refresh time when relevant.
    var navigationSubtitle: Text? {
        guard let lastUpdatedAt = viewModel.lastUpdatedAt else {
            return nil
        }

        switch viewModel.state {
        case .loaded, .empty:
            return Text("Last updated at \(lastUpdatedAt, format: .dateTime.hour().minute())")
        case .idle, .loading, .failed:
            return nil
        }
    }

    /// Informational card that explains why the app is currently using demo data.
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

    /// Banner that explains live-session status and exposes OAuth-related actions.
    var liveAuthorizationBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(authenticationSession.statusTitle, systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)

            Text(authenticationSession.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(authenticationSession.isAuthenticated ? "Manage OAuth" : "Connect OAuth") {
                    isOAuthSheetPresented = true
                }
                .buttonStyle(.borderedProminent)

                if authenticationSession.canValidateCurrentSession {
                    Button(authenticationSession.isValidatingCurrentSession ? "Validating…" : "Validate Session") {
                        Task {
                            await authenticationSession.validateCurrentSession()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(authenticationSession.isValidatingCurrentSession)
                }

                if authenticationSession.isAuthenticated {
                    Button("Forget Session", role: .destructive) {
                        authenticationSession.signOut()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if authenticationSession.shouldShowSessionValidationStatus {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(authenticationSession.sessionValidationTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(authenticationSession.sessionValidationMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
    }

    @ViewBuilder
    /// Resolves the visible content state for the current search lifecycle.
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

    /// Home state shown before a search runs, including suggestion shortcuts.
    var idleState: some View {
        VStack(alignment: .leading, spacing: 16) {
            ContentUnavailableView {
                Label("Search the Catalog", systemImage: "magnifyingglass.circle")
            } description: {
                Text("Start with one of the demo suggestions or type any product name.")
            }
            .frame(maxWidth: .infinity)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        Task {
                            await viewModel.applySuggestion(suggestion)
                        }
                    } label: {
                        Text(suggestion)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
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
        .accessibilityIdentifier("searchIdleState")
    }

    /// Loading card shown while a search request is in flight.
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

    /// Empty state shown when the search succeeds but no products match the query.
    var emptyState: some View {
        ContentUnavailableView {
            Label("No products found", systemImage: "shippingbox")
        } description: {
            Text("Try a broader query or use one of the suggestions from the home state.")
        }
        .accessibilityIdentifier("searchEmptyState")
    }

    /// Builds the search failure state with retry affordances and recovery guidance.
    /// - Parameter error: Domain error produced by the search request.
    /// - Returns: A view describing the failure and offering a retry action.
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
        .accessibilityIdentifier("searchErrorState")
    }

    /// Result list shown when the latest search returned one or more products.
    var resultsState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.results.count) Results")
                    .font(.headline)
                    .accessibilityIdentifier("resultsCountLabel")

                Text("Last query: \(viewModel.lastSubmittedQuery)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("resultsQueryLabel")
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
        .accessibilityIdentifier("searchResultsState")
    }

    /// Background gradient shared by all search states.
    var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.92, green: 0.96, blue: 1.00), location: 0.00),
                .init(color: Color(red: 0.88, green: 0.93, blue: 0.99), location: 0.22),
                .init(color: Color(red: 0.84, green: 0.90, blue: 0.98), location: 0.45),
                .init(color: Color(red: 0.78, green: 0.86, blue: 0.97), location: 0.68),
                .init(color: Color(red: 0.70, green: 0.81, blue: 0.95), location: 0.85),
                .init(color: Color(red: 0.62, green: 0.76, blue: 0.94), location: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Card fill used across the different search states.
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.82))
    }

    /// Toggles the current keyboard focus state for the search field.
    func toggleSearchFocus() {
        isSearchFieldFocused.toggle()
    }
}

private struct SearchNavigationSubtitleStyle: ViewModifier {
    /// Optional subtitle shown under the navigation title.
    let subtitle: Text?

    @ViewBuilder
    /// Applies the subtitle only when one is available.
    func body(content: Content) -> some View {
        if let subtitle {
            content.navigationSubtitle(subtitle)
        } else {
            content
        }
    }
}

#if os(macOS)
/// Leaves the default macOS title behavior untouched.
private struct SearchNavigationTitleStyle: ViewModifier {
    /// Preserves the platform default navigation bar behavior on macOS.
    func body(content: Content) -> some View {
        content
    }
}
#else
/// Applies the iOS navigation title and toolbar styling for the search screen.
private struct SearchNavigationTitleStyle: ViewModifier {
    /// Applies iOS-specific navigation bar styling for the search flow.
    func body(content: Content) -> some View {
        content
            .modifier(AppNavigationBarStyle())
    }
}
#endif

/// Applies platform-specific text-field tweaks without duplicating the search bar layout.
private struct SearchTextFieldPlatformStyle: ViewModifier {
    /// Applies text-input behavior tailored to the current platform.
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
