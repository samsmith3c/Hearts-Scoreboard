//
//  Hearts_ScoreboardUITests.swift
//  Hearts ScoreboardUITests
//

import XCTest

final class Hearts_ScoreboardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// End-to-end regression for the bug-hunt fixes:
    /// 1. Start a 4-player game and record a hand.
    /// 2. Go home, flip the player-count picker to 6 (used to desync scores
    ///    and crash on resume), verify the OR divider, then Resume — the
    ///    scoreboard must come back as a 4-player game.
    /// 3. Kill and relaunch the app — the game must survive and resume with
    ///    its hand history intact.
    func testGameSurvivesCountChangeAndRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        skipTutorialIfPresent(app)

        // ── Home screen: force 4 players, fill names, start ────────────────
        let fourSegment = app.buttons["4"]
        XCTAssertTrue(fourSegment.waitForExistence(timeout: 5), "player-count picker not found")
        fourSegment.tap()

        fillPlayerNames(app, count: 4)

        app.buttons["Start New Game"].tap()
        tapAlertButtonIfPresent(app, "Start New Game")   // abandon-existing-game confirm
        tapAlertButtonIfPresent(app, "Continue")         // not-tracking warning

        XCTAssertTrue(app.staticTexts["PAST HANDS"].waitForExistence(timeout: 5),
                      "scoreboard did not appear")

        // ── Record one hand: 5 / 9 / 8 / 4 ────────────────────────────────
        enterHand(app, scores: ["5", "9", "8", "4"])
        XCTAssertTrue(app.staticTexts["👈"].waitForExistence(timeout: 5),
                      "committed hand row did not appear")
        attachScreenshot(app, name: "1-scoreboard-with-hand")

        // ── Home → change count to 6 → verify divider → Resume ─────────────
        app.buttons["scoreboard.home"].tap()
        XCTAssertTrue(app.buttons["Resume Game"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["OR"].exists, "OR divider missing on home screen")
        attachScreenshot(app, name: "2-home-resume-or-divider")

        app.buttons["6"].tap()   // the old crash trigger

        app.buttons["Resume Game"].tap()
        XCTAssertTrue(app.staticTexts["PAST HANDS"].waitForExistence(timeout: 5),
                      "scoreboard did not survive resume after count change")
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.staticTexts["👈"].exists, "hand history lost after resume")
        attachScreenshot(app, name: "3-resumed-after-count-change")

        // ── Kill and relaunch: the game must persist ───────────────────────
        app.terminate()
        app.launch()

        XCTAssertTrue(app.buttons["Resume Game"].waitForExistence(timeout: 5),
                      "active game did not survive relaunch")
        attachScreenshot(app, name: "4-relaunch-home-offers-resume")

        app.buttons["Resume Game"].tap()
        XCTAssertTrue(app.staticTexts["PAST HANDS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["👈"].waitForExistence(timeout: 5),
                      "hand history lost across relaunch")
        attachScreenshot(app, name: "5-resumed-after-relaunch")
    }

    // MARK: - Helpers

    private func skipTutorialIfPresent(_ app: XCUIApplication) {
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
        }
    }

    private func tapAlertButtonIfPresent(_ app: XCUIApplication, _ label: String) {
        let button = app.alerts.buttons[label]
        if button.waitForExistence(timeout: 2) {
            button.tap()
        }
    }

    private func fillPlayerNames(_ app: XCUIApplication, count: Int) {
        for i in 1...count {
            let field = app.textFields["Player \(i) name"]
            guard field.waitForExistence(timeout: 3) else { continue }
            let value = field.value as? String ?? ""
            if value.isEmpty || value == "Player \(i) name" {
                field.tap()
                // "\n" drives the field's own submit: focus advances field to
                // field and the last one dismisses the keyboard.
                field.typeText("P\(i)\n")
            }
        }
        waitForKeyboardToDismiss(app)
    }

    private func enterHand(_ app: XCUIApplication, scores: [String]) {
        // The input row is the only set of "0"-placeholder fields on screen.
        let fields = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "0"))
        XCTAssertEqual(fields.count, scores.count, "unexpected number of score inputs")
        for (i, score) in scores.enumerated() {
            let field = fields.element(boundBy: i)
            field.tap()
            field.typeText(score)   // number pad — no return key
        }
        waitForKeyboardToDismiss(app)
        let plus = app.buttons["scoreboard.commit"]
        XCTAssertTrue(plus.waitForExistence(timeout: 3), "commit button not found")
        XCTAssertTrue(plus.isEnabled, "commit button not enabled at total 26")
        plus.tap()
    }

    /// The keyboard covers the lower half of both screens; nothing below it is
    /// tappable until it's gone. Tap the toolbar Done (retrying — the first
    /// tap can land while the toolbar is still animating in) and wait it out.
    private func waitForKeyboardToDismiss(_ app: XCUIApplication) {
        for _ in 0..<10 {
            if app.keyboards.count == 0 { return }
            let done = app.buttons["Done"]
            if done.exists && done.isHittable {
                done.tap()
            }
            usleep(500_000)
        }
        XCTAssertEqual(app.keyboards.count, 0, "keyboard did not dismiss")
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
