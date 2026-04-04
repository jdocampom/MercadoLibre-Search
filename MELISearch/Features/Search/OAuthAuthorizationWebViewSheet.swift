import SwiftUI
import WebKit

/// Embedded Mercado Libre authorization browser that captures the registered redirect URL once it loads.
struct OAuthAuthorizationWebViewSheet: View {
    /// Dismiss action used after capturing the callback or when the user closes the browser.
    @Environment(\.dismiss) private var dismiss
    /// Shared OAuth session used to match the callback URL against the registered redirect.
    let authenticationSession: MELIAuthenticationSession
    /// Authorization URL generated for the current OAuth attempt.
    let authorizationURL: URL
    /// Called when the embedded browser reaches the registered callback URL.
    let onCapture: (URL) -> Void

    /// WebKit page backing the SwiftUI web view.
    @State private var page = WebPage(configuration: .init())
    /// Prevents repeated loads when SwiftUI refreshes the sheet.
    @State private var didStartLoading = false
    /// Prevents cancel cleanup when the callback was already captured.
    @State private var didCaptureCallback = false
    /// Load errors surfaced inline instead of leaving the sheet blank.
    @State private var loadErrorMessage: String?

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
    }
}

private extension OAuthAuthorizationWebViewSheet {
    /// Main browser content with loading and failure affordances.
    @ViewBuilder
    var content: some View {
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
    }

    /// Chooses the platform-appropriate location for the close button.
    var closeToolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .primaryAction
#else
        .topBarTrailing
#endif
    }

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
}
