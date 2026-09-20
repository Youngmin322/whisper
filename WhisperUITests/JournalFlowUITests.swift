//
//  JournalFlowUITests.swift
//  WhisperUITests
//

import XCTest

final class JournalFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testJournalFlowFromMomentToSavedEntry() throws {
        let app = launchApp()

        addMoment("바람이 좋아 한 정거장 먼저 내려 걸었다.", in: app)
        openJournalReview(in: app)

        let sourcePickerButton = app.buttons["journal.sourcePickerButton"]
        XCTAssertTrue(sourcePickerButton.waitForExistence(timeout: 2))
        sourcePickerButton.tap()

        let insertButton = app.buttons["journal.insertSourcesButton"]
        XCTAssertTrue(insertButton.waitForExistence(timeout: 2))
        insertButton.tap()

        let bodyField = app.textViews["journal.bodyField"]
        XCTAssertTrue(bodyField.waitForExistence(timeout: 2))
        XCTAssertTrue((bodyField.value as? String)?.contains("바람이 좋아") == true)

        let titleField = app.textFields["journal.titleField"]
        titleField.tap()
        titleField.typeText("천천히 걸은 저녁")

        let saveButton = app.buttons["journal.saveButton"]
        XCTAssertTrue(saveButton.isEnabled)
        assertContained(saveButton, in: app)
        saveButton.tap()

        XCTAssertTrue(app.navigationBars["일기"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["천천히 걸은 저녁"].exists)
        XCTAssertTrue(app.staticTexts["journal.bodyPreview"].label.contains("바람이 좋아"))
    }

    func testPrimaryActionsRemainVisibleWithLargeTextAndKeyboard() throws {
        let app = launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXL")

        addMoment("작은 화면에서도 남겨야 하는 오늘의 순간", in: app)

        let reviewButton = app.buttons["home.reviewJournalButton"]
        scrollToElement(reviewButton, in: app)
        assertContained(reviewButton, in: app)
        reviewButton.tap()

        let sourcePickerButton = app.buttons["journal.sourcePickerButton"]
        XCTAssertTrue(sourcePickerButton.waitForExistence(timeout: 2))
        assertContained(sourcePickerButton, in: app)
        sourcePickerButton.tap()

        let insertButton = app.buttons["journal.insertSourcesButton"]
        XCTAssertTrue(insertButton.waitForExistence(timeout: 2))
        scrollToElement(insertButton, in: app)
        insertButton.tap()

        let bodyField = app.textViews["journal.bodyField"]
        XCTAssertTrue(bodyField.waitForExistence(timeout: 2))
        bodyField.tap()
        bodyField.typeText("\n\n큰 글자에서도 입력할 수 있다.")

        let saveButton = app.navigationBars.buttons["journal.saveButton"]
        XCTAssertTrue(saveButton.isHittable)
        assertContained(saveButton, in: app)
    }

    private func launchApp(contentSizeCategory: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-hasSeenWelcome",
            "YES"
        ]

        if let contentSizeCategory {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                contentSizeCategory
            ]
        }

        app.launch()
        XCTAssertTrue(app.buttons["home.recordButton"].waitForExistence(timeout: 5))
        return app
    }

    private func addMoment(_ text: String, in app: XCUIApplication) {
        app.buttons["home.recordButton"].tap()

        let contentField = app.textFields["record.contentField"]
        XCTAssertTrue(contentField.waitForExistence(timeout: 2))
        contentField.tap()
        contentField.typeText(text)

        let saveButton = app.buttons["record.saveButton"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.buttons["home.reviewJournalButton"].waitForExistence(timeout: 3))
    }

    private func openJournalReview(in app: XCUIApplication) {
        app.buttons["home.reviewJournalButton"].tap()
        XCTAssertTrue(app.textViews["journal.bodyField"].waitForExistence(timeout: 2))
    }

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func assertContained(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let windowFrame = app.windows.firstMatch.frame
        let elementFrame = element.frame

        XCTAssertGreaterThanOrEqual(elementFrame.minX, windowFrame.minX, file: file, line: line)
        XCTAssertGreaterThanOrEqual(elementFrame.minY, windowFrame.minY, file: file, line: line)
        XCTAssertLessThanOrEqual(elementFrame.maxX, windowFrame.maxX, file: file, line: line)
        XCTAssertLessThanOrEqual(elementFrame.maxY, windowFrame.maxY, file: file, line: line)
    }
}
