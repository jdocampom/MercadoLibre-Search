import Observation
import SwiftUI

/// Minimal UI that walks the user through the Mercado Libre OAuth flow.
struct OAuthSetupSheet: View {
    /// Dismiss action for closing the sheet after completion or cancellation.
    @Environment(\.dismiss) private var dismiss
    /// Shared session object that drives Mercado Libre OAuth state and token exchange.
    @Bindable var authenticationSession: MELIAuthenticationSession
    /// Full callback URL pasted or captured after browser authorization.
    @State private var callbackInput = ""
    /// Browser session context used to present the embedded Mercado Libre authorization page.
    @State private var browserSession: BrowserSession?

    /// Local validation or submission errors shown inline within the sheet.
    @State private var localErrorMessage: String?
    /// Tracks whether the code exchange request is currently in flight.
    @State private var isSubmitting = false

    /// Renders the OAuth walkthrough form used to authorize, capture the callback, and validate the session.
    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Text(authenticationSession.statusTitle)
                        .font(.headline)

                    Text(authenticationSession.statusMessage)
                        .foregroundStyle(.secondary)

                    if let localErrorMessage {
                        Text(localErrorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Authorize") {
                    Button("Open Mercado Libre Authorization Page") {
                        openAuthorizationPage()
                    }
                    .buttonStyle(.borderedProminent)

                    Text("This opens the Mercado Libre consent flow inside the new SwiftUI web view and watches the current page URL until the registered callback finishes loading.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Callback") {
                    TextField("https://jdocampom.com/meli/callback?code=...", text: $callbackInput, axis: .vertical)

                    Text("When the embedded web view reaches the registered callback URL, MELI Search copies it here and starts exchanging the authorization code automatically. You can still paste it manually and use the button if needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Exchange Authorization Code") {
                        submitCallback()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(callbackInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }

                if authenticationSession.canValidateCurrentSession {
                    validateSessionSection
                }

                if authenticationSession.isAuthenticated {
                    Section("Session") {
                        Button("Forget Stored Session", role: .destructive) {
                            authenticationSession.signOut()
                        }
                    }
                }
            }
            .sheet(item: $browserSession) { browserSession in
                OAuthAuthorizationWebViewSheet(
                    authenticationSession: authenticationSession,
                    authorizationURL: browserSession.authorizationURL
                ) { callbackURL in
                    let callbackValue = callbackURL.absoluteString
                    callbackInput = callbackValue
                    submitCallback(using: callbackValue)
                }
            }
            .navigationTitle("Mercado Libre OAuth")
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authenticationSession.latestError) { _, latestError in
                guard !isAuthorizing, let latestError else {
                    return
                }

                localErrorMessage = latestError.localizedDescription
            }
            .onChange(of: authenticationSession.isAuthenticated) { _, isAuthenticated in
                guard isAuthenticated else {
                    return
                }

                localErrorMessage = nil
                dismiss()
            }
        }
    }
}

private extension OAuthSetupSheet {
    /// Indicates whether the user is still inside the embedded authorization browser flow.
    var isAuthorizing: Bool {
        if browserSession != nil {
            return true
        }

        if case .authorizing = authenticationSession.status {
            return true
        }

        return false
    }

    /// Returns the correct toolbar placement for the current platform.
    var toolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .primaryAction
#else
        .topBarTrailing
#endif
    }

    /// Validation section kept separate so the main form stays easy to scan.
    var validateSessionSection: some View {
        Section("Validate Session") {
            Text(authenticationSession.sessionValidationTitle)
                .font(.headline)

            Text(authenticationSession.sessionValidationMessage)
                .foregroundStyle(.secondary)

            Button(authenticationSession.isValidatingCurrentSession ? "Validating…" : "Check /users/me") {
                validateSession()
            }
            .buttonStyle(.bordered)
            .disabled(isSubmitting || authenticationSession.isValidatingCurrentSession)
        }
    }

    /// Opens Mercado Libre's authorization page inside the embedded SwiftUI web view.
    func openAuthorizationPage() {
        localErrorMessage = nil

        do {
            let authorizationURL = try authenticationSession.authorizationURL()
            browserSession = BrowserSession(authorizationURL: authorizationURL)
        } catch {
            localErrorMessage = AppError.from(error).localizedDescription
        }
    }

    /// Exchanges the callback data for tokens and dismisses the sheet on success.
    func submitCallback(using callbackValue: String? = nil) {
        guard !isSubmitting else {
            return
        }

        let callback = (callbackValue ?? callbackInput).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !callback.isEmpty else {
            return
        }

        callbackInput = callback
        localErrorMessage = nil
        isSubmitting = true

        Task {
            let didAuthorize = await authenticationSession.completeAuthorization(from: callback)

            await MainActor.run {
                isSubmitting = false

                if didAuthorize {
                    dismiss()
                } else if let latestError = authenticationSession.latestError {
                    localErrorMessage = latestError.localizedDescription
                }
            }
        }
    }

    /// Confirms the current bearer token against `/users/me` and keeps any failure visible in the sheet.
    func validateSession() {
        localErrorMessage = nil

        Task {
            let didValidate = await authenticationSession.validateCurrentSession()

            await MainActor.run {
                if !didValidate, let latestError = authenticationSession.latestError {
                    localErrorMessage = latestError.localizedDescription
                }
            }
        }
    }

    /// Lightweight sheet state used to present a concrete Mercado Libre authorization request.
    struct BrowserSession: Identifiable {
        /// Stable identifier for SwiftUI sheet presentation.
        let id = UUID()
        /// Authorization page URL generated for the current OAuth attempt.
        let authorizationURL: URL
    }
}
