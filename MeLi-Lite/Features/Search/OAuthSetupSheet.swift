import Observation
import SwiftUI

/// Minimal UI that walks the user through the Mercado Libre OAuth flow.
struct OAuthSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Shared session object that drives Mercado Libre OAuth state and token exchange.
    @Bindable var authenticationSession: MercadoLibreAuthenticationSession

    /// Full callback URL or raw code pasted by the user after browser authorization.
    @State private var callbackInput = ""
    /// Local validation or submission errors shown inline within the sheet.
    @State private var localErrorMessage: String?
    /// Tracks whether the exchange request is currently in flight.
    @State private var isSubmitting = false

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

                    Text("Approve the app in the browser, then paste the full callback URL returned by your redirect page. If necessary, you can also paste the raw authorization code only.")
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
}
