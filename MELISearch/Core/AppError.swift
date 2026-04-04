import Foundation

/// Domain error used to normalize transport, decoding, and configuration failures.
enum AppError: Error, LocalizedError, Equatable, Sendable {
    /// Live mode was requested without a configured OAuth token.
    case missingAccessToken
    /// Live mode is missing the OAuth app id, client secret, or redirect URL.
    case missingOAuthConfiguration
    /// The callback URL could not be parsed or did not match the current OAuth attempt.
    case invalidAuthorizationCallback
    /// The app could not build a valid Mercado Libre endpoint URL.
    case invalidURL
    /// The server response was not an HTTP payload the app understands.
    case invalidResponse
    /// Mercado Libre rejected the token with HTTP 401.
    case unauthorized
    /// Mercado Libre refused the request with HTTP 403.
    case forbidden
    /// Mercado Libre returned any other non-success HTTP status code.
    case httpStatus(Int)
    /// JSON decoding failed after a successful transport response.
    case decoding(String)
    /// URLSession reported a transport-level failure.
    case transport(URLError.Code)
    /// Fallback wrapper for unexpected errors not covered above.
    case unknown(String)

    /// Maps arbitrary errors into the app's domain-specific error model.
    /// - Parameter error: Source error raised by the repository or transport layer.
    /// - Returns: The closest `AppError` representation for the provided failure.
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let decodingError = error as? DecodingError {
            return .decoding(decodingError.localizedDescription)
        }

        if let urlError = error as? URLError {
            return .transport(urlError.code)
        }

        return .unknown(error.localizedDescription)
    }

    /// User-facing error message shown in SwiftUI error states.
    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Live Mercado Libre requests need a valid access token."
        case .missingOAuthConfiguration:
            return "OAuth is not fully configured for live Mercado Libre requests."
        case .invalidAuthorizationCallback:
            return "The callback URL could not be validated for this OAuth attempt."
        case .invalidURL, .invalidResponse:
            return "The app could not understand the server response."
        case .unauthorized:
            return "The configured Mercado Libre token is not valid anymore."
        case .forbidden:
            return "Mercado Libre rejected this request."
        case let .httpStatus(statusCode):
            return "The server answered with status code \(statusCode)."
        case .decoding:
            return "The app received data in an unexpected format."
        case let .transport(code):
            switch code {
            case .notConnectedToInternet:
                return "You're offline right now."
            case .cannotFindHost, .dnsLookupFailed:
                return "The Mercado Libre server name could not be resolved."
            case .cannotConnectToHost:
                return "The Mercado Libre server could not be reached."
            case .timedOut:
                return "The request took too long to finish."
            default:
                return "The network request could not be completed."
            }
        case .unknown:
            return "Something unexpected happened."
        }
    }

    /// Recovery guidance displayed when the app can suggest a next action.
    var recoverySuggestion: String? {
        switch self {
        case .missingAccessToken:
            return "Authorize the app with OAuth, provide MELI_ACCESS_TOKEN locally, or switch back to demo mode."
        case .missingOAuthConfiguration:
            return "Configure MELI_APP_ID, MELI_CLIENT_SECRET, and MELI_REDIRECT_URL, or switch back to demo mode."
        case .invalidAuthorizationCallback:
            return "Start Mercado Libre authorization again from the app so it can generate a fresh callback for this OAuth attempt."
        case .unauthorized, .forbidden:
            return "Refresh your credentials or switch the app back to demo mode."
        case .transport(.notConnectedToInternet):
            return "Check your network connection and try again."
        case .transport(.cannotFindHost), .transport(.dnsLookupFailed):
            return "If you're online, DNS resolution may be failing on the device or simulator. Retry, switch networks, or use demo mode."
        case .transport(.cannotConnectToHost):
            return "Retry the request, then check firewall, VPN, or proxy settings if the problem continues."
        default:
            return "Try the request again in a moment."
        }
    }

    /// Detailed diagnostic text intended for logging and debugging.
    var developerDescription: String {
        switch self {
        case .missingAccessToken:
            return "No valid Mercado Libre access token was available for the live data source."
        case .missingOAuthConfiguration:
            return "Missing MELI_APP_ID, MELI_CLIENT_SECRET, or MELI_REDIRECT_URL while trying to use OAuth."
        case .invalidAuthorizationCallback:
            return "Failed to validate the provided callback URL against the registered redirect and pending OAuth state."
        case .invalidURL:
            return "Failed to construct a valid Mercado Libre URL request."
        case .invalidResponse:
            return "Received a non-HTTP or malformed response object."
        case .unauthorized:
            return "Mercado Libre returned HTTP 401."
        case .forbidden:
            return "Mercado Libre returned HTTP 403."
        case let .httpStatus(statusCode):
            return "Mercado Libre returned unexpected HTTP status \(statusCode)."
        case let .decoding(message):
            return "Failed to decode Mercado Libre payload: \(message)"
        case let .transport(code):
            switch code {
            case .cannotFindHost:
                return "URLSession transport error: \(code.rawValue) (cannot find host)"
            case .dnsLookupFailed:
                return "URLSession transport error: \(code.rawValue) (DNS lookup failed)"
            case .cannotConnectToHost:
                return "URLSession transport error: \(code.rawValue) (cannot connect to host)"
            default:
                return "URLSession transport error: \(code.rawValue)"
            }
        case let .unknown(message):
            return "Unexpected error: \(message)"
        }
    }
}
