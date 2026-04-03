//
//  MeLi_LiteTests.swift
//  MeLi-LiteTests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

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
}
