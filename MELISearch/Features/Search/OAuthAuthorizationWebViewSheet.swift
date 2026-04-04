import SwiftUI
import WebKit

/// Embedded Mercado Libre authorization browser.
struct OAuthAuthorizationWebViewSheet: View {
    /// Dismiss action used after capturing the callback or when the user closes the browser.
    @Environment(\.dismiss) private var dismiss
    /// Shared OAuth session used to match the callback URL against the registered redirect.
    let authenticationSession: MELIAuthenticationSession
    /// Authorization URL generated for the current OAuth attempt.
    let authorizationURL: URL
    /// Called when the embedded browser reaches the registered callback URL.
    let onCapture: (URL) -> Void

#if os(macOS)
    /// Prevents cancel cleanup when the callback was already captured.
    @State private var didCaptureCallback = false
    /// Load errors surfaced inline instead of leaving the sheet blank.
    @State private var loadErrorMessage: String?
    /// Tracks the current browser loading state for the inline progress indicator.
    @State private var isLoading = true
    /// Mirrors `WKWebView.estimatedProgress` so the sheet can show meaningful progress feedback.
    @State private var estimatedProgress = 0.0
#else
    /// WebKit page backing the SwiftUI web view on iOS-family platforms.
    @State private var page = WebPage(configuration: .init())
    /// Prevents repeated loads when SwiftUI refreshes the sheet.
    @State private var didStartLoading = false
    /// Prevents cancel cleanup when the callback was already captured.
    @State private var didCaptureCallback = false
    /// Load errors surfaced inline instead of leaving the sheet blank.
    @State private var loadErrorMessage: String?
#endif

    /// Renders the OAuth web content and captures the callback URL when it matches the registered redirect.
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Mercado Libre")
                .toolbar {
                    ToolbarItem(placement: closeToolbarPlacement) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
        }
#if os(macOS)
        .onDisappear {
            guard !didCaptureCallback, !authenticationSession.isAuthenticated else {
                return
            }

            authenticationSession.cancelInteractiveAuthorization()
        }
#else
        .task {
            await loadAuthorizationPageIfNeeded()
        }
        .onChange(of: page.url) { _, currentURL in
            attemptCaptureCallback(using: currentURL)
        }
        .onChange(of: page.isLoading) { _, _ in
            attemptCaptureCallback(using: page.url)
        }
        .onDisappear {
            guard !didCaptureCallback, !authenticationSession.isAuthenticated else {
                return
            }

            authenticationSession.cancelInteractiveAuthorization()
        }
#endif
    }
}

private extension OAuthAuthorizationWebViewSheet {
    /// Main browser content with loading and failure affordances.
    @ViewBuilder
    var content: some View {
#if os(macOS)
        if let loadErrorMessage {
            ContentUnavailableView {
                Label("Authorization Page Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadErrorMessage)
            }
        } else {
            OAuthAuthorizationWebView(
                authorizationURL: authorizationURL,
                canHandleAuthorizationCallback: authenticationSession.canHandleAuthorizationCallback(_:),
                onNavigationStateChange: updateNavigationState(isLoading:estimatedProgress:),
                onLoadError: updateLoadError(_:),
                onCapture: captureCallback(from:)
            )
                .overlay(alignment: .top) {
                    if isLoading {
                        ProgressView(value: estimatedProgress)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
        }
#else
        if let loadErrorMessage {
            ContentUnavailableView {
                Label("Authorization Page Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadErrorMessage)
            }
        } else {
            WebView(page)
                .overlay(alignment: .top) {
                    if page.isLoading {
                        ProgressView(value: page.estimatedProgress)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
        }
#endif
    }

    /// Chooses the platform-appropriate location for the close button.
    var closeToolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .primaryAction
#else
        .topBarTrailing
#endif
    }

#if os(macOS)
    /// Applies browser loading updates from the wrapped `WKWebView`.
    func updateNavigationState(isLoading: Bool, estimatedProgress: Double) {
        guard
            self.isLoading != isLoading
                || abs(self.estimatedProgress - estimatedProgress) > 0.001
        else {
            return
        }

        self.isLoading = isLoading
        self.estimatedProgress = estimatedProgress
    }

    /// Stores load failures unless the callback was already captured and the navigation was cancelled on purpose.
    func updateLoadError(_ message: String?) {
        guard !didCaptureCallback else {
            return
        }

        guard loadErrorMessage != message else {
            return
        }

        loadErrorMessage = message
    }

    /// Captures the registered redirect as soon as WebKit attempts to navigate to it.
    func captureCallback(from currentURL: URL) {
        guard !didCaptureCallback else {
            return
        }

        didCaptureCallback = true
        onCapture(currentURL)
        dismiss()
    }
#else
    /// Loads the Mercado Libre authorization request only once per sheet presentation.
    func loadAuthorizationPageIfNeeded() async {
        guard !didStartLoading else {
            return
        }

        didStartLoading = true

        do {
            for try await _ in page.load(URLRequest(url: authorizationURL)) {}
        } catch {
            if !didCaptureCallback {
                loadErrorMessage = error.localizedDescription
            }
        }
    }

    /// Captures the registered redirect only after the callback page finished loading in the embedded browser.
    func attemptCaptureCallback(using currentURL: URL?) {
        guard !didCaptureCallback, !page.isLoading, let currentURL else {
            return
        }

        guard authenticationSession.canHandleAuthorizationCallback(currentURL) else {
            return
        }

        didCaptureCallback = true
        onCapture(currentURL)
        dismiss()
    }
#endif
}

#if os(macOS)
/// A thin multiplatform `WKWebView` wrapper used instead of SwiftUI's `WebView`.
///
/// The SwiftUI wrapper was triggering layout recursion warnings on macOS and failed to
/// load Mercado Libre's authorization page reliably. Using `WKWebView` directly keeps
/// the OAuth flow on Apple's supported WebKit stack while preserving callback capture.
private struct OAuthAuthorizationWebView {
    /// Initial OAuth request generated for the current authorization attempt.
    let authorizationURL: URL
    /// Callback matcher supplied by the authentication session.
    let canHandleAuthorizationCallback: (URL) -> Bool
    /// Reports loading state and progress to the sheet.
    let onNavigationStateChange: (_ isLoading: Bool, _ estimatedProgress: Double) -> Void
    /// Reports user-visible load errors.
    let onLoadError: (String?) -> Void
    /// Called when WebKit attempts to navigate to the registered callback URL.
    let onCapture: (URL) -> Void
}

#if os(macOS)
extension OAuthAuthorizationWebView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.loadAuthorizationPageIfNeeded(in: webView)
    }
}
#else
extension OAuthAuthorizationWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.loadAuthorizationPageIfNeeded(in: webView)
    }
}
#endif

private extension OAuthAuthorizationWebView {
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// Latest parent configuration pushed from SwiftUI updates.
        var parent: OAuthAuthorizationWebView

        /// Avoids reloading the same authorization request during view refreshes.
        private var loadedAuthorizationURL: URL?
        /// KVO tokens that mirror `WKWebView` state back into SwiftUI.
        private var observations: [NSKeyValueObservation] = []

        init(parent: OAuthAuthorizationWebView) {
            self.parent = parent
        }

        /// Creates and configures the shared web view instance for the current presentation.
        func makeWebView() -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = self
            webView.uiDelegate = self

#if os(iOS)
            webView.allowsBackForwardNavigationGestures = true
#endif

            observeNavigationState(for: webView)
            loadAuthorizationPageIfNeeded(in: webView)
            return webView
        }

        /// Loads the OAuth request once for the current sheet presentation.
        func loadAuthorizationPageIfNeeded(in webView: WKWebView) {
            guard loadedAuthorizationURL != parent.authorizationURL else {
                return
            }

            loadedAuthorizationURL = parent.authorizationURL
            publishLoadError(nil)
            webView.load(URLRequest(url: parent.authorizationURL))
        }

        /// Mirrors WebKit loading state into the SwiftUI sheet.
        func observeNavigationState(for webView: WKWebView) {
            observations = [
                webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                    Task { @MainActor [weak self] in
                        self?.publishNavigationState(for: webView)
                    }
                },
                webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                    Task { @MainActor [weak self] in
                        self?.publishNavigationState(for: webView)
                    }
                }
            ]
        }

        /// Pushes the current WebKit loading state back into SwiftUI on the next main-run-loop turn.
        func publishNavigationState(for webView: WKWebView) {
            let isLoading = webView.isLoading
            let estimatedProgress = webView.estimatedProgress

            DispatchQueue.main.async { [parent] in
                parent.onNavigationStateChange(isLoading, estimatedProgress)
            }
        }

        /// Surfaces browser load errors on the next main-run-loop turn.
        func publishLoadError(_ message: String?) {
            DispatchQueue.main.async { [parent] in
                parent.onLoadError(message)
            }
        }

        /// Handles provisional redirects and stops once the OAuth callback is reached.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let currentURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if parent.canHandleAuthorizationCallback(currentURL) {
                parent.onCapture(currentURL)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        /// Loads `target="_blank"` and popup requests into the same view so the OAuth flow can continue.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil else {
                return nil
            }

            if let currentURL = navigationAction.request.url {
                if parent.canHandleAuthorizationCallback(currentURL) {
                    parent.onCapture(currentURL)
                } else {
                    webView.load(navigationAction.request)
                }
            }

            return nil
        }

        /// Clears any previous browser error after a successful load.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            publishNavigationState(for: webView)
            publishLoadError(nil)
        }

        /// Surfaces provisional navigation failures, ignoring the cancellation we trigger after capture.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleNavigationFailure(error, in: webView)
        }

        /// Surfaces committed navigation failures, ignoring benign cancellation noise.
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleNavigationFailure(error, in: webView)
        }

        /// Normalizes WebKit failures into a concise user-visible message.
        func handleNavigationFailure(_ error: Error, in webView: WKWebView) {
            guard !shouldIgnoreNavigationFailure(error) else {
                publishNavigationState(for: webView)
                return
            }

            publishNavigationState(for: webView)
            publishLoadError(userFacingMessage(for: error))
        }

        /// Redirects and callback cancellation routinely surface as `NSURLErrorCancelled`; these are expected.
        func shouldIgnoreNavigationFailure(_ error: Error) -> Bool {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue
        }

        /// Formats the failure with recovery guidance when the underlying error maps cleanly to `AppError`.
        func userFacingMessage(for error: Error) -> String {
            let appError = AppError.from(error)

            if let recoverySuggestion = appError.recoverySuggestion {
                return "\(appError.localizedDescription) \(recoverySuggestion)"
            }

            return appError.localizedDescription
        }
    }
}
#endif
