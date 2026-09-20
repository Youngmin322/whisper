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

        let bodyPreview = app.staticTexts["journal.bodyPreview"]
        XCTAssertTrue(bodyPreview.waitForExistence(timeout: 4))
        XCTAssertTrue(bodyPreview.label.contains("바람이 좋아"))

        app.buttons["journal.addReflectionButton"].tap()

        let reflectionField = app.textViews["journal.reflectionField"]
        XCTAssertTrue(reflectionField.waitForExistence(timeout: 2))
        reflectionField.tap()
        reflectionField.typeText("천천히 가도 괜찮다.")

        let saveButton = app.buttons["journal.saveButton"]
        XCTAssertTrue(saveButton.isEnabled)
        assertContained(saveButton, in: app)
        saveButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["journal.saveFeedback"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.navigationBars["일기"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["천천히 가도 괜찮다."].exists)
    }

    func testPrimaryActionsRemainVisibleWithLargeTextAndKeyboard() throws {
        let app = launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXL")

        addMoment("작은 화면에서도 남겨야 하는 오늘의 순간", in: app)

        let reviewButton = app.buttons["home.reviewJournalButton"]
        scrollToElement(reviewButton, in: app)
        assertContained(reviewButton, in: app)
        reviewButton.tap()

        let createButton = app.buttons["journal.createDraftButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2))
        scrollToElement(createButton, in: app)
        assertContained(createButton, in: app)
        createButton.tap()

        let reflectionButton = app.buttons["journal.addReflectionButton"]
        XCTAssertTrue(reflectionButton.waitForExistence(timeout: 4))
        scrollToElement(reflectionButton, in: app)
        reflectionButton.tap()

        let skipButton = app.buttons["journal.skipReflectionButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 2))
        XCTAssertTrue(skipButton.isHittable)
        assertContained(skipButton, in: app)

        let reflectionField = app.textViews["journal.reflectionField"]
        reflectionField.tap()
        reflectionField.typeText("큰 글자에서도 입력할 수 있다.")

        let saveButton = app.buttons["journal.saveButton"]
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

        let createButton = app.buttons["journal.createDraftButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 2))
        createButton.tap()
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
