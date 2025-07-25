//
//  swift_node_like_node_REDUITestsLaunchTests.swift
//  swift-node-like-node-REDUITests
//
//  Created by k22036kk on 2025/06/16.
//

import XCTest

@MainActor
final class Swift_node_like_node_REDUITestsLaunchTests: XCTestCase {

    @MainActor
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false

        // Setup permission handlers once for all tests
        setupPermissionHandlers()
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()

        // Use optimized launch helper
        app.launchOptimized()
        app.tap()

        // Quick verification that app launched successfully
        XCTAssertTrue(verifyAppLaunched(app), "App should launch successfully")

        // Handle permission dialogs if they appear
        app.handlePermissionDialog()

        // Only take screenshot when necessary
        addOptimizedScreenshot(name: "Launch Screen", app: app)
    }
}
