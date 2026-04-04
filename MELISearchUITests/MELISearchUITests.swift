//
//  MELISearchUITests.swift
//  MeLi-LiteUITests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import XCTest

/// Demo-mode UI smoke tests that exercise the main search-to-detail flow.
nonisolated final class MELISearchUITests: XCTestCase {
    /// Stops execution immediately after the first failure to keep UI diagnostics readable.
    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Verifies that searching a demo fixture navigates to its detail screen.
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

    /// Verifies that a typed query filters the demo catalog down to matching rows.
    @MainActor
    func testTypedSearchShowsMatchingDemoResult() throws {
        let app = launchDemoApp()
        performSearch("Kindle", in: app)

        XCTAssertTrue(app.element(withID: "productRow_DEMO-KINDLE-PAPERWHITE").waitForExistence(timeout: 5))
        XCTAssertFalse(app.element(withID: "productRow_DEMO-IPHONE-15-PRO").exists)
    }

    /// Verifies that the authenticated live OAuth banner starts collapsed and can be expanded on demand.
    @MainActor
    func testAuthenticatedLiveOAuthBannerStartsCollapsedAndExpands() throws {
        let app = launchLiveAuthenticatedApp()

        let bannerToggle = app.element(withID: "liveAuthorizationBannerToggle")

        XCTAssertTrue(bannerToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(bannerToggle.value as? String, "collapsed")

        bannerToggle.click()
        XCTAssertTrue(waitForValue("expanded", in: bannerToggle))

        bannerToggle.click()
        XCTAssertTrue(waitForValue("collapsed", in: bannerToggle))
    }
}

private extension MELISearchUITests {
    /// Launches the app with the deterministic demo-mode configuration used by UI tests.
    /// - Returns: A running application instance ready for assertions.
    @MainActor
    func launchDemoApp() -> XCUIApplication {
        let app = configuredDemoApp()
        app.launch()
        return app
    }

    /// Launches the app in live mode with a deterministic authenticated session used for UI testing.
    /// - Returns: A running application instance ready for banner assertions.
    @MainActor
    func launchLiveAuthenticatedApp() -> XCUIApplication {
        let app = configuredLiveAuthenticatedApp()
        app.launch()
        return app
    }

    /// Builds the application instance with stable locale and demo-only environment overrides.
    /// - Returns: A configured but not yet launched application.
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

    /// Builds the application instance in live mode with a deterministic authenticated banner state.
    /// - Returns: A configured but not yet launched application.
    @MainActor
    func configuredLiveAuthenticatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["MELI_DATA_SOURCE"] = "live"
        app.launchEnvironment["MELI_SITE_ID"] = "MCO"
        app.launchEnvironment["MELI_ACCESS_TOKEN"] = ""
        app.launchEnvironment["MELI_APP_ID"] = ""
        app.launchEnvironment["MELI_CLIENT_SECRET"] = ""
        app.launchEnvironment["MELI_REDIRECT_URL"] = ""
        app.launchEnvironment["MELI_UI_TEST_AUTH_STATE"] = "authenticated"
        return app
    }

    /// Types a query into the search field and taps the primary submit button.
    /// - Parameters:
    ///   - query: Search text to submit.
    ///   - app: Running application under test.
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

    /// Waits until an element publishes the expected accessibility value.
    /// - Parameters:
    ///   - expectedValue: Accessibility value that should be exposed by the element.
    ///   - element: UI element under observation.
    ///   - timeout: Maximum wait in seconds before failing the expectation.
    /// - Returns: `true` when the value matches within the timeout window.
    @MainActor
    func waitForValue(_ expectedValue: String, in element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

private extension XCUIApplication {
    /// Returns the first UI element matching the provided accessibility identifier.
    /// - Parameter identifier: Accessibility identifier assigned by the app.
    /// - Returns: The first matching element in the application hierarchy.
    func element(withID identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier].firstMatch
    }
}
