import Observation
import SwiftUI

/// Minimal UI that walks the user through the Mercado Libre OAuth flow.
struct OAuthSetupSheet: View {
    /// Dismiss action for closing the sheet after completion or cancellation.
    @Environment(\.dismiss) private var dismiss
    /// System URL opener used to hand off authorization to the browser.
    @Environment(\.openURL) private var openURL
    /// Shared session object that drives Mercado Libre OAuth state and token exchange.
    @Bindable var authenticationSession: MELIAuthenticationSession

    /// Full callback URL pasted by the user after browser authorization.
    @State private var callbackInput = ""
    /// Local validation or submission errors shown inline within the sheet.
    @State private var localErrorMessage: String?
    /// Tracks whether the exchange request is currently in flight.
    @State private var isSubmitting = false

    /// Renders the OAuth walkthrough form used to authorize, paste the callback, and validate the session.
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

                    Text("Approve the app in the browser, then paste the full callback URL returned by your redirect page. The app validates the redirect origin and OAuth state before exchanging the code.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Callback") {
                    TextField("https://jdocampom.com/meli/callback?code=...", text: $callbackInput, axis: .vertical)
                        .modifier(OAuthCallbackTextFieldStyle())

                    Button("Exchange Authorization Code") {
                        submitCallback()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(callbackInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }

                if authenticationSession.canValidateCurrentSession {
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

                if authenticationSession.isAuthenticated {
                    Section("Session") {
                        Button("Forget Stored Session", role: .destructive) {
                            authenticationSession.signOut()
                        }
                    }
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
        }
    }
}

/// Applies platform-specific text field behavior so callback input stays unmodified.
private struct OAuthCallbackTextFieldStyle: ViewModifier {
    /// Applies platform-specific input behavior while preserving the pasted callback value verbatim.
    func body(content: Content) -> some View {
#if os(macOS)
        content
#else
        content
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
#endif
    }
}

private extension OAuthSetupSheet {
    /// Returns the correct toolbar placement for the current platform.
    var toolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .primaryAction
#else
        .topBarTrailing
#endif
    }

    /// Opens Mercado Libre's authorization page in the system browser.
    func openAuthorizationPage() {
        localErrorMessage = nil

        do {
            let authorizationURL = try authenticationSession.authorizationURL()
            openURL(authorizationURL)
        } catch {
            localErrorMessage = AppError.from(error).localizedDescription
        }
    }

    /// Exchanges the pasted callback data for tokens and dismisses the sheet on success.
    func submitCallback() {
        localErrorMessage = nil
        isSubmitting = true

        Task {
            let didAuthorize = await authenticationSession.completeAuthorization(from: callbackInput)

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
}
