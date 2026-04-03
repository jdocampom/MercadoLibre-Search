//
//  MELISearchUITestsLaunchTests.swift
//  MELISearchUITests
//
//  Created by Juan Diego Ocampo on 4/2/26.
//

import XCTest

/// Launch-level UI smoke test that verifies the demo search screen appears successfully.
nonisolated final class MELISearchUITestsLaunchTests: XCTestCase {
    /// Requests a fresh application launch for each configured UI run.
    nonisolated override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    /// Stops execution immediately after the first failure to simplify launch diagnostics.
    nonisolated override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app in demo mode and captures a screenshot after the search field appears.
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
