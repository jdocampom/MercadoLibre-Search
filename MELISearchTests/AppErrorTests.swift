import Foundation
import Testing
@testable import MELISearch

struct AppErrorTests {
    @Test
    func fromReturnsExistingAppErrorUnchanged() {
        let error = AppError.forbidden

        #expect(AppError.from(error) == .forbidden)
    }

    @Test
    func fromMapsURLErrorIntoTransportCase() {
        let mappedError = AppError.from(URLError(.timedOut))

        #expect(mappedError == .transport(.timedOut))
    }

    @Test
    func fromMapsDecodingErrorIntoDecodingCase() throws {
        struct Payload: Decodable {
            let count: Int
        }

        let data = Data("{\"count\":\"wrong\"}".utf8)

        do {
            _ = try JSONDecoder().decode(Payload.self, from: data)
            Issue.record("Expected JSON decoding to fail.")
        } catch {
            let mappedError = AppError.from(error)

            switch mappedError {
            case let .decoding(message):
                #expect(message.isEmpty == false)
            default:
                Issue.record("Expected AppError.decoding but received \(mappedError).")
            }
        }
    }

    @Test
    func cannotFindHostUsesDNSFocusedMessaging() {
        let error = AppError.transport(.cannotFindHost)

        #expect(error.errorDescription == "The Mercado Libre server name could not be resolved.")
        #expect(
            error.recoverySuggestion
                == "If you're online, DNS resolution may be failing on the device or simulator. Retry, switch networks, or use demo mode."
        )
        #expect(error.developerDescription == "URLSession transport error: -1003 (cannot find host)")
    }

    @Test
    func dnsLookupFailureUsesDNSFocusedMessaging() {
        let error = AppError.transport(.dnsLookupFailed)

        #expect(error.errorDescription == "The Mercado Libre server name could not be resolved.")
        #expect(
            error.recoverySuggestion
                == "If you're online, DNS resolution may be failing on the device or simulator. Retry, switch networks, or use demo mode."
        )
        #expect(error.developerDescription == "URLSession transport error: -1006 (DNS lookup failed)")
    }

    @Test
    func unauthorizedUsesCredentialFocusedMessaging() {
        let error = AppError.unauthorized

        #expect(error.errorDescription == "The configured Mercado Libre token is not valid anymore.")
        #expect(error.recoverySuggestion == "Refresh your credentials or switch the app back to demo mode.")
        #expect(error.developerDescription == "Mercado Libre returned HTTP 401.")
    }

    @Test
    func invalidAuthorizationCallbackMentionsRetryingTheSameOAuthAttempt() {
        let error = AppError.invalidAuthorizationCallback

        #expect(error.errorDescription == "The callback URL could not be validated for this OAuth attempt.")
        #expect(
            error.recoverySuggestion
                == "Start Mercado Libre authorization again from the app so it can generate a fresh callback for this OAuth attempt."
        )
        #expect(
            error.developerDescription
                == "Failed to validate the provided callback URL against the registered redirect and pending OAuth state."
        )
    }

    @Test
    func missingAccessTokenUsesLiveOAuthGuidance() {
        let error = AppError.missingAccessToken

        #expect(error.errorDescription == "Live Mercado Libre requests need a valid access token.")
        #expect(
            error.recoverySuggestion
                == "Authorize the app with OAuth, provide MELI_ACCESS_TOKEN locally, or switch back to demo mode."
        )
    }

    @Test
    func timedOutTransportUsesRequestDurationMessaging() {
        let error = AppError.transport(.timedOut)

        #expect(error.errorDescription == "The request took too long to finish.")
        #expect(error.recoverySuggestion == "Try the request again in a moment.")
        #expect(error.developerDescription == "URLSession transport error: -1001")
    }
}
