//
//  MELISearchUITests.swift
//  MeLi-LiteUITests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import XCTest

nonisolated final class MELISearchUITests: XCTestCase {
    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSearchNavigatesToProductDetail() throws {
        let app = launchDemoApp()
        performSearch("iPhone", in: app)

        let resultRow = app.element(withID: "productRow_DEMO-IPHONE-15-PRO")
        XCTAssertTrue(resultRow.waitForExistence(timeout: 5))
        resultRow.tap()

        XCTAssertTrue(app.element(withID: "productDetailScreen_DEMO-IPHONE-15-PRO").waitForExistence(timeout: 5))
        XCTAssertTrue(app.element(withID: "productDetailShippingCard").waitForExistence(timeout: 5))
    }

    @MainActor
    func testTypedSearchShowsMatchingDemoResult() throws {
        let app = launchDemoApp()
        performSearch("Kindle", in: app)

        XCTAssertTrue(app.element(withID: "productRow_DEMO-KINDLE-PAPERWHITE").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element(withID: "productRow_DEMO-IPHONE-15-PRO").exists)
    }

}

private extension MELISearchUITests {
    @MainActor
    func launchDemoApp() -> XCUIApplication {
        let app = configuredDemoApp()
        app.launch()
        return app
    }

    @MainActor
    func configuredDemoApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["MELI_DATA_SOURCE"] = "demo"
        app.launchEnvironment["MELI_SITE_ID"] = "MCO"
        app.launchEnvironment["MELI_ACCESS_TOKEN"] = ""
        app.launchEnvironment["MELI_APP_ID"] = ""
        app.launchEnvironment["MELI_CLIENT_SECRET"] = ""
        app.launchEnvironment["MELI_REDIRECT_URL"] = ""
        return app
    }

    @MainActor
    func performSearch(_ query: String, in app: XCUIApplication) {
        let searchField = app.element(withID: "searchTextField")
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(query)

        let searchButton = app.element(withID: "searchButton")
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        searchButton.tap()
    }
}

private extension XCUIApplication {
    func element(withID identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier].firstMatch
    }
}
