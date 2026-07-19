//
//  vivobodyUITests.swift
//  vivobodyUITests
//
//  UI workflow coverage for active-workout persistence and partial
//  save behavior. Tests launch with debug-only seed arguments so each
//  run starts from deterministic on-device SwiftData state.
//

import XCTest

final class vivobodyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testActiveWorkoutDraftRestoresAfterRelaunch() throws {
        var app = launchApp(arguments: ["--ui-test-reset", "--ui-test-active-partial"])
        waitFor(app.buttons["activeWorkoutMiniBar"])

        app.terminate()

        app = launchApp(arguments: ["--ui-test-active-partial"])
        waitFor(app.buttons["activeWorkoutMiniBar"])
    }

    @MainActor
    func testPartialWorkoutCanBeSavedToHistory() throws {
        let app = launchApp(arguments: ["--ui-test-reset", "--ui-test-active-partial"])

        waitFor(app.buttons["activeWorkoutMiniBar"]).tap()
        waitFor(app.buttons["endWorkoutButton"]).tap()
        waitFor(app.buttons["Save Workout"]).tap()

        XCTAssertFalse(app.buttons["activeWorkoutMiniBar"].waitForExistence(timeout: 1))

        tapTab("History", in: app)
        waitFor(app.descendants(matching: .any)["historySessionRow"])
    }

    @MainActor
    func testScheduledWorkoutStartsFromToday() throws {
        let app = launchApp(arguments: ["--ui-test-reset", "--ui-test-scheduled-template"])
        let start = waitFor(app.buttons["Start Scheduled Test"])

        for _ in 0..<4 where !start.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(start.isHittable)
        start.tap()
        waitFor(app.buttons["endWorkoutButton"])
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor
    @discardableResult
    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Timed out waiting for \(element)")
        return element
    }

    @MainActor
    private func tapTab(_ name: String, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons[name]
        if tabButton.waitForExistence(timeout: 2) {
            tabButton.tap()
            return
        }
        waitFor(app.buttons[name]).tap()
    }
}
