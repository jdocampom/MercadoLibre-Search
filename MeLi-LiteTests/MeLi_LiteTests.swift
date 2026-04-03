//
//  MeLi_LiteTests.swift
//  MeLi-LiteTests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import Foundation
import Testing
@testable import MeLi_Lite

@Suite("MeLi Lite")
struct MeLi_LiteTests {}

@Suite("App Configuration")
struct AppConfigurationTests {
    @Test
    func defaultsToDemoWithoutLiveInputs() {
        let configuration = AppConfiguration.resolve(environment: [:])

        #expect(configuration.dataSource == .demo)
        #expect(configuration.siteID == "MCO")
        #expect(configuration.accessToken == nil)
    }

    @Test
    func explicitDemoWinsOverTokenPresence() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_DATA_SOURCE": "demo",
            "MELI_ACCESS_TOKEN": "test-token",
            "MELI_SITE_ID": "MLA"
        ])

        #expect(configuration.dataSource == .demo)
        #expect(configuration.siteID == "MLA")
        #expect(configuration.accessToken == "test-token")
    }

    @Test
    func tokenStillEnablesLiveWhenSourceIsUnset() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_ACCESS_TOKEN": "test-token"
        ])

        #expect(configuration.dataSource == .live)
        #expect(configuration.siteID == "MCO")
    }

    @Test
    func resolvesOAuthConfigurationFromEnvironment() {
        let configuration = AppConfiguration.resolve(environment: [
            "MELI_APP_ID": "123456",
            "MELI_CLIENT_SECRET": "secret",
            "MELI_REDIRECT_URL": "https://example.com/callback",
            "MELI_SITE_ID": "MCO"
        ])

        #expect(configuration.oauthConfiguration?.clientID == "123456")
        #expect(configuration.oauthConfiguration?.clientSecret == "secret")
        #expect(configuration.oauthConfiguration?.redirectURL.absoluteString == "https://example.com/callback")
        #expect(configuration.oauthConfiguration?.authorizationHost == "auth.mercadolibre.com.co")
    }
}

@Suite("Mercado Libre OAuth")
struct MercadoLibreOAuthConfigurationTests {
    @Test
    func resolvesKnownAuthorizationHostForMCO() {
        #expect(MercadoLibreOAuthConfiguration.defaultAuthorizationHost(forSiteID: "MCO") == "auth.mercadolibre.com.co")
    }

    @Test
    func leavesUnknownSitesWithoutDefaultAuthorizationHost() {
        #expect(MercadoLibreOAuthConfiguration.defaultAuthorizationHost(forSiteID: "UNKNOWN") == nil)
    }
}
