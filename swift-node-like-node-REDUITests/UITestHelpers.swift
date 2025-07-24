//
//  UITestHelpers.swift
//  swift-node-like-node-REDUITests
//
//  Created by Assistant on 2025/07/24.
//

import XCTest

extension XCUIApplication {
    /// Launches app with optimized settings for faster UI testing
    func launchOptimized() {
        // Disable animations and unnecessary features
        launchEnvironment["UI_TEST_DISABLE_ANIMATION"] = "YES"
        launchEnvironment["DISABLE_LOGGING"] = "YES"
        launchEnvironment["DISABLE_NETWORKING"] = "YES"  // If applicable
        launchArguments.append("--uitesting")
        launchArguments.append("--disable-hardware-keyboards")

        launch()
    }

    /// Quick app launch verification
    func waitForAppToLaunch(timeout: TimeInterval = 3.0) -> Bool {
        return windows.firstMatch.waitForExistence(timeout: timeout)
    }

    /// Handle common permission dialogs if they appear
    func handlePermissionDialog() {
        // Check for location permission dialog
        let locationAlert = alerts["Allow 'swift-node-like-node-RED' to access your location?"]
        if locationAlert.exists {
            locationAlert.buttons["Allow While Using App"].tap()
            return
        }

        // Check for notification permission dialog
        let notificationAlert = alerts.firstMatch
        if notificationAlert.exists {
            if notificationAlert.buttons["Allow"].exists {
                notificationAlert.buttons["Allow"].tap()
            } else if notificationAlert.buttons["OK"].exists {
                notificationAlert.buttons["OK"].tap()
            }
        }
    }
}

extension XCTestCase {
    /// Setup common permission handlers for UI tests
    func setupPermissionHandlers() {
        addUIInterruptionMonitor(withDescription: "Location Permission") { alert in
            let allowButton = alert.buttons["Allow While Using App"]
            if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
    }

    /// Only take screenshots in debug mode or CI environment
    func addOptimizedScreenshot(name: String, app: XCUIApplication) {
        guard shouldTakeScreenshot() else { return }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .deleteOnSuccess  // Only keep on failure
        add(attachment)
    }

    private func shouldTakeScreenshot() -> Bool {
        return ProcessInfo.processInfo.environment["CI"] != nil
            || ProcessInfo.processInfo.environment["DEBUG_UI_TESTS"] != nil
    }

    /// Quick app verification with minimal overhead
    func verifyAppLaunched(_ app: XCUIApplication, timeout: TimeInterval = 3.0) -> Bool {
        return app.windows.firstMatch.waitForExistence(timeout: timeout)
    }
}
