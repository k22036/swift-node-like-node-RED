//
//  swift_node_like_node_REDUITestsLaunchTests.swift
//  swift-node-like-node-REDUITests
//
//  Created by k22036kk on 2025/06/16.
//

import XCTest

final class Swift_node_like_node_REDUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Automatically allow location permission dialog if it appears
        addUIInterruptionMonitor(withDescription: "Location Permission") { alert in
            let allowButton = alert.buttons["Allow While Using App"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
        app.tap()  // Tap the screen to trigger dialog detection

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
