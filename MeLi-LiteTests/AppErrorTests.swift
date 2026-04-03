import Foundation
import Testing
@testable import MeLi_Lite

struct AppErrorTests {
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
}
