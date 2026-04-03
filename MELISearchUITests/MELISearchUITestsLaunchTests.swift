//
//  MELISearchUITestsLaunchTests.swift
//  MELISearchUITests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import XCTest

nonisolated final class MELISearchUITestsLaunchTests: XCTestCase {

    nonisolated override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MELI_DATA_SOURCE"] = "demo"
        app.launchEnvironment["MELI_ACCESS_TOKEN"] = ""
        app.launchEnvironment["MELI_APP_ID"] = ""
        app.launchEnvironment["MELI_CLIENT_SECRET"] = ""
        app.launchEnvironment["MELI_REDIRECT_URL"] = ""
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["searchTextField"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
