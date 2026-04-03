//
//  MeLi_LiteUITests.swift
//  MeLi-LiteUITests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import XCTest

nonisolated final class MeLi_LiteUITests: XCTestCase {

    nonisolated override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    nonisolated override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testDemoSearchShowsResultAndDetail() throws {
        let app = XCUIApplication()
        app.launch()

        let searchDockButton = app.buttons["searchTextField"]
        XCTAssertTrue(searchDockButton.waitForExistence(timeout: 3))

        searchDockButton.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.typeText("iPhone")
        app.buttons["searchButton"].tap()

        let productTitle = app.staticTexts["iPhone 15 Pro 256 GB Natural Titanium"]
        XCTAssertTrue(productTitle.waitForExistence(timeout: 3))

        productTitle.tap()

        let detailPrice = app.staticTexts["ARS 1,699,999.00"]
        XCTAssertTrue(detailPrice.waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
