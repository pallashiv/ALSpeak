import XCTest

/// End-to-end tests that drive the real app, plus Apple's automated accessibility audit
/// (contrast, hit-target size, Dynamic Type, missing labels, clipped text…) on each main screen.
///
/// Every launch uses `-UITesting`, which gives the app a fresh in-memory copy of the
/// bundled phrase library, so tests never depend on each other or on a device's data.
final class ALSpeakUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    // MARK: Helpers

    /// Waits for an element rather than failing on the first frame.
    @discardableResult
    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5,
                         file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing: \(element)", file: file, line: line)
        return element
    }

    /// Runs Apple's accessibility audit. Two kinds of finding are skipped, deliberately:
    /// - **Contrast**: the audit estimates it from screen pixels and misreads composite
    ///   controls (a tinted card with a white icon circle, a capsule tab on the page
    ///   background). Every color pairing the app uses is instead checked exactly, in light
    ///   and dark mode, by `PaletteContrastTests` in the unit tests.
    /// - **"Partially supported" Dynamic Type**: the always-visible bottom bar and the tab
    ///   row stop growing at a set size so they can't push the phrases off screen (the bar
    ///   offers the Large Content Viewer instead). Text that doesn't scale at all still fails.
    /// - **Clipped text with no element**: reported for text cut by the bottom edge of a
    ///   scrolling list (e.g. a Settings footer half off screen). Clipping the audit can
    ///   attribute to an element still fails.
    private func audit(file: StaticString = #filePath, line: UInt = #line) throws {
        try app.performAccessibilityAudit { issue in
            switch issue.auditType {
            case .contrast:
                return true
            case .dynamicType where issue.compactDescription.localizedCaseInsensitiveContains("partially"):
                return true
            case .textClipped where issue.element == nil:
                return true
            default:
                // Name the offending element in the log so failures are easy to track down.
                let element = issue.element
                print("Accessibility issue: \(issue.compactDescription) — label '\(element?.label ?? "-")', frame \(element?.frame ?? .zero)")
                return false
            }
        }
    }

    private func openPlace(_ name: String) {
        waitFor(app.buttons[name]).tap()
        waitFor(app.navigationBars[name])
    }

    // MARK: Speaking

    func testTappingAPhraseShowsItFullScreenAndCloses() {
        openPlace("Restaurant")
        waitFor(app.buttons["I'd like to order now"]).tap()

        // The full-screen display shows the text with Close / Stop / Say again.
        let close = waitFor(app.buttons["Close"])
        XCTAssertTrue(app.staticTexts["I'd like to order now"].exists)
        close.tap()
        XCTAssertTrue(app.buttons["Close"].waitForNonExistence(timeout: 3))
    }

    func testCategoryTabsSwitchPhrases() {
        openPlace("Restaurant")
        XCTAssertTrue(waitFor(app.buttons["Ordering"]).isSelected, "Restaurant should open on its first category")

        app.buttons["Payment"].tap()
        waitFor(app.buttons["Could we have the bill, please?"])
        XCTAssertFalse(app.buttons["I'd like to order now"].exists)
    }

    // MARK: Quick Respond

    func testYesAndNoAreAlwaysOnTheBar() {
        waitFor(app.buttons["Yes"])
        waitFor(app.buttons["No"])
        openPlace("Doctor")
        XCTAssertTrue(app.buttons["Yes"].exists)
        XCTAssertTrue(app.buttons["Emergency help"].exists)
    }

    func testMorePanelShowsAllRepliesAndClosesAfterSpeaking() {
        waitFor(app.buttons["More replies"]).tap()
        let maybe = waitFor(app.buttons["Maybe"])
        XCTAssertTrue(app.buttons["Could you repeat that?"].exists)
        XCTAssertTrue(app.buttons["Type a message"].exists)

        maybe.tap()
        XCTAssertTrue(app.buttons["Type a message"].waitForNonExistence(timeout: 3), "Panel should close after a reply")
    }

    // MARK: Type to speak

    func testTypedTextCanBeSavedToTheCurrentPlace() {
        openPlace("Restaurant")
        waitFor(app.buttons["More replies"]).tap()
        waitFor(app.buttons["Type a message"]).tap()

        let field = waitFor(app.descendants(matching: .any)["Text to speak"])
        field.typeText("Extra ice please")
        waitFor(app.buttons["Save to Restaurant"]).tap()
        waitFor(app.staticTexts["Saved to Restaurant → My Phrases"])

        app.navigationBars["Type to Speak"].buttons["Close"].tap()
        waitFor(app.buttons["My Phrases"]).tap()
        waitFor(app.buttons["Extra ice please"])
    }

    // MARK: Editing

    func testAddingAPlaceFromSettings() {
        waitFor(app.buttons["Settings"]).tap()
        waitFor(app.buttons["Edit places"]).tap()
        waitFor(app.buttons["Add a place"]).tap()

        let name = waitFor(app.textFields["Place name"])
        name.tap()
        name.typeText("Church")
        app.navigationBars["New Place"].buttons["Save"].tap()
        app.navigationBars["Edit Places"].buttons["Done"].tap()
        app.navigationBars["Settings"].buttons["Done"].tap()

        waitFor(app.buttons["Church"]).tap()
        waitFor(app.navigationBars["Church"])
    }

    func testAddingAPhraseInEditMode() {
        openPlace("Home")
        app.navigationBars["Home"].buttons["Edit"].tap()
        waitFor(app.buttons["Add phrase to Comfort"]).tap()

        let text = waitFor(app.descendants(matching: .any)["Phrase text"])
        text.tap()
        text.typeText("Could you open the window?")
        app.navigationBars["New Phrase"].buttons["Save"].tap()
        app.navigationBars["Home"].buttons["Done"].tap()

        waitFor(app.buttons["Could you open the window?"])
    }

    // MARK: Accessibility audits

    func testHomeScreenPassesAccessibilityAudit() throws {
        waitFor(app.buttons["Restaurant"])
        try audit()
    }

    func testPhraseBoardPassesAccessibilityAudit() throws {
        openPlace("Restaurant")
        try audit()
    }

    func testMorePanelPassesAccessibilityAudit() throws {
        waitFor(app.buttons["More replies"]).tap()
        waitFor(app.buttons["Maybe"])
        try audit()
    }

    func testSpokenPhraseScreenPassesAccessibilityAudit() throws {
        openPlace("Restaurant")
        waitFor(app.buttons["Could I see the menu?"]).tap()
        waitFor(app.buttons["Close"])
        try audit()
    }

    func testSettingsPassesAccessibilityAudit() throws {
        waitFor(app.buttons["Settings"]).tap()
        waitFor(app.navigationBars["Settings"])
        try audit()
    }
}
