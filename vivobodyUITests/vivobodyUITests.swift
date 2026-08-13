//
//  vivobodyUITests.swift
//  vivobodyUITests
//
//  UI workflow and accessibility-audit coverage for the Today and
//  active-workout surfaces. Tests launch with debug-only seed arguments
//  so each run starts from deterministic on-device SwiftData state.
//

import XCTest

final class vivobodyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTodayAccessibilityAudit() throws {
        let app = launchApp(arguments: ["--ui-test-reset"])
        waitFor(app.buttons["Start Workout"])

        try performAccessibilityAudit(
            in: app,
            knownCompositedContrastLabels: [
                "Consistency",
                "Consistent",
                "Low",
                "No history",
                "Current training development · tap for details",
            ],
            knownOCRFalsePositiveCount: 3
        )
    }

    @MainActor
    func testActiveWorkoutAccessibilityAudit() throws {
        let app = launchApp(arguments: ["--ui-test-reset", "--ui-test-active-partial"])
        // Today merges the running workout into its pinned CTA, so the
        // MiniBar pill only exists on the other tabs.
        waitFor(app.buttons["activeWorkoutResumeBar"]).tap()
        waitFor(app.buttons["endWorkoutButton"])

        try performAccessibilityAudit(
            in: app,
            knownCompositedContrastLabels: [
                "Reps in reserve",
                "135 x 8",
            ],
            knownOCRFalsePositiveCount: 0
        )
    }

    @MainActor
    func testActiveWorkoutDraftRestoresAfterRelaunch() throws {
        var app = launchApp(arguments: ["--ui-test-reset", "--ui-test-active-partial"])
        waitFor(app.buttons["activeWorkoutResumeBar"])

        app.terminate()

        app = launchApp(arguments: ["--ui-test-active-partial"])
        waitFor(app.buttons["activeWorkoutResumeBar"])
    }

    @MainActor
    func testPartialWorkoutCanBeSavedToHistory() throws {
        let app = launchApp(arguments: ["--ui-test-reset", "--ui-test-active-partial"])

        waitFor(app.buttons["activeWorkoutResumeBar"]).tap()
        waitFor(app.buttons["endWorkoutButton"]).tap()
        waitFor(app.buttons["Save Workout"]).tap()

        XCTAssertFalse(app.buttons["activeWorkoutResumeBar"].waitForExistence(timeout: 1))

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

    /// XCUI's contrast audit evaluates the source layers of translucent
    /// SwiftUI glass and LED controls rather than their final composited
    /// pixels. These deterministic fixtures clear WCAG contrast in the
    /// failure screenshots, so handle only their exact labels. The Today
    /// legend also produces three element-detection findings without an
    /// element identity even though its complete visible vocabulary is
    /// exposed by the containing button; pin that exact count so any new
    /// issue still fails the audit.
    @MainActor
    private func performAccessibilityAudit(
        in app: XCUIApplication,
        knownCompositedContrastLabels: Set<String>,
        knownOCRFalsePositiveCount: Int
    ) throws {
        try app.performAccessibilityAudit(for: .contrast) { issue in
            guard issue.auditType == .contrast,
                  let label = issue.element?.label,
                  knownCompositedContrastLabels.contains(label)
            else { return false }
            return true
        }

        var handledOCRFalsePositives = 0
        try app.performAccessibilityAudit(for: [
            .elementDetection,
            .hitRegion,
            .sufficientElementDescription,
            .dynamicType,
            .textClipped,
            .trait,
        ]) { issue in
            guard issue.auditType == .elementDetection,
                  issue.element == nil,
                  issue.compactDescription == "Potentially inaccessible text",
                  handledOCRFalsePositives < knownOCRFalsePositiveCount
            else { return false }
            handledOCRFalsePositives += 1
            return true
        }
        XCTAssertEqual(handledOCRFalsePositives, knownOCRFalsePositiveCount)
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
