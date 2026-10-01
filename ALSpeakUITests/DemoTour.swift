import XCTest

/// A scripted walkthrough used to record the portfolio demo video and screenshots.
/// Skipped in normal test runs; enable with:
///
///     TEST_RUNNER_DEMO_TOUR=1 TEST_RUNNER_DEMO_SHOTS=/path/to/dir \
///       xcodebuild test ... -only-testing:ALSpeakUITests/DemoTour
final class DemoTour: XCTestCase {
    private var app: XCUIApplication!
    private var shotsDirectory: URL?

    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["DEMO_TOUR"] != nil, "Demo tour only runs when DEMO_TOUR is set")
        continueAfterFailure = false
        shotsDirectory = environment["DEMO_SHOTS"].map { URL(fileURLWithPath: $0) }
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-DemoProfile"]
        app.launch()
    }

    /// Writes the current time to `<DEMO_SHOTS>/<name>.txt`, so the recording can be trimmed.
    private func mark(_ name: String) {
        guard let shotsDirectory else { return }
        try? String(Date().timeIntervalSince1970)
            .write(to: shotsDirectory.appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func shot(_ name: String) {
        guard let shotsDirectory else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation
            .write(to: shotsDirectory.appendingPathComponent("\(name).png"))
    }

    private func tap(_ element: XCUIElement, then seconds: Double = 1.2) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        element.tap()
        pause(seconds)
    }

    private func closeOverlayIfShown() {
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 1) { close.tap(); pause(0.8) }
    }

    func testTour() {
        // Home
        XCTAssertTrue(app.buttons["Restaurant"].waitForExistence(timeout: 5))
        mark("start")
        pause(2)
        shot("01-home")

        // Restaurant board → speak a phrase
        tap(app.buttons["Restaurant"], then: 1.5)
        shot("02-board")
        tap(app.buttons["Could I see the menu?"], then: 1.0)
        shot("03-spoken")
        pause(2)
        closeOverlayIfShown()

        // Another category
        tap(app.buttons["Payment"])
        tap(app.buttons["Could we have the bill, please?"], then: 3)
        closeOverlayIfShown()

        // Quick replies: More panel
        tap(app.buttons["More replies"], then: 1.5)
        shot("04-more")
        tap(app.buttons["Thank you"], then: 2.5)
        closeOverlayIfShown()

        // Favorites on Family & Friends
        tap(app.buttons["BackButton"], then: 1)
        tap(app.buttons["Family & Friends"], then: 1.5)
        shot("05-favorites")
        tap(app.buttons["I love you"], then: 2.5)
        closeOverlayIfShown()

        // Type to speak and save
        tap(app.buttons["More replies"])
        tap(app.buttons["Type a message"], then: 1)
        let field = app.descendants(matching: .any)["Text to speak"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        // Dismiss iOS's one-time keyboard tip if it appears.
        let keyboardTip = app.buttons["Continue"]
        if keyboardTip.waitForExistence(timeout: 1.5) { keyboardTip.tap(); pause(0.5) }
        field.typeText("Can we go for a walk later?")
        pause(1)
        shot("06-type")
        tap(app.buttons["Speak"], then: 2.5)
        tap(app.buttons["Save to Family & Friends"], then: 1.5)
        app.navigationBars["Type to Speak"].buttons["Close"].tap()
        pause(1)

        // Edit mode
        app.navigationBars["Family & Friends"].buttons["Edit"].tap()
        pause(1.5)
        shot("07-edit")
        app.navigationBars["Family & Friends"].buttons["Done"].tap()
        pause(0.8)

        // SOS: press and hold
        let sos = app.buttons["Emergency help"]
        XCTAssertTrue(sos.waitForExistence(timeout: 3))
        sos.press(forDuration: 1.3)
        pause(1.2)
        shot("08-emergency")
        pause(1.5)
        closeOverlayIfShown()

        // Settings
        tap(app.buttons["BackButton"], then: 0.8)
        tap(app.buttons["Settings"], then: 1.5)
        shot("09-settings")
        app.swipeUp()
        pause(1.5)
        shot("10-touch")
        app.navigationBars["Settings"].buttons["Done"].tap()
        pause(1.5)
        mark("end")
    }
}
