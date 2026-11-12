import XCTest

@MainActor
final class LearnerJourneyUITests: XCTestCase {
    private let timeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Cases 01 and 04, plus the task state exposed to accessibility in case 10.
    func testCreatesGoalAndTaskAndRetainsCompletionAfterRelaunch() throws {
        let app = launchFreshApp()
        let goal = "Learn Python"
        let task = "Learn variables"
        try createFirstGoal(goal, in: app)
        try addTask(task, to: goal, in: app)

        let checkButton = app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", task, "Incomplete")).firstMatch
        try tapVisible(checkButton, in: app)
        try tapVisible(app.buttons["Show 1 done tasks"], in: app)
        let completedCheck = app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", task, "Completed")).firstMatch
        XCTAssertTrue(completedCheck.waitForExistence(timeout: timeout))

        app.terminate()
        app.launch()
        try tapVisible(app.buttons["tab_sessions"], in: app)
        let goalCard = app.buttons[goal]
        XCTAssertTrue(goalCard.waitForExistence(timeout: timeout))
        XCTAssertTrue((goalCard.value as? String)?.contains("1 of 1 tasks done") == true)
        try tapVisible(goalCard, in: app)
        try tapVisible(app.buttons["Show 1 done tasks"], in: app)
        XCTAssertTrue(completedCheck.waitForExistence(timeout: timeout))
    }

    func testVideoDiscoveryIsVisibleWithoutAVideoNoteAndPresentsRecommendations() throws {
        let app = launchFreshApp()
        let goal = "Learn Python"
        let task = "Learn variables"
        try createFirstGoal(goal, in: app)
        try addTask(task, to: goal, in: app)

        let videoAction = app.buttons["Find learning video for \(task)"]
        try tapVisible(videoAction, in: app)

        XCTAssertTrue(app.navigationBars["Learning videos"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Done"].isHittable)
    }

    // Case 02.
    func testCanSkipSetupAndAddAGoalLater() throws {
        let app = launchFreshApp()
        try tapVisible(app.buttons["Start my learning setup"], in: app)
        try tapVisible(app.buttons["I'll calibrate as I go (Skip)"], in: app)
        try finishSetup(in: app)

        XCTAssertTrue(app.staticTexts["Add a learning goal first"].waitForExistence(timeout: timeout))
        try tapVisible(app.buttons["tab_today"], in: app)
        try tapVisible(app.buttons["tab_sessions"], in: app)
        try tapVisible(app.buttons["Add learning topic"], in: app)
        try enterGoal("Study Spanish", in: app)
        try finishSetup(in: app)

        XCTAssertTrue(app.buttons["Study Spanish"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["Add a learning goal first"].exists)
    }

    // Case 05.
    func testGentleCheckInIsVisibleInProfileAfterRelaunch() throws {
        let app = launchFreshApp()
        try tapVisible(app.buttons["tab_today"], in: app)
        let gentle = app.buttons["Gentle, Audio & rest"]
        try tapVisible(gentle, in: app)
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: gentle)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: timeout), .completed)
        try tapVisible(app.buttons["tab_profile"], in: app)
        let profileRating = app.staticTexts["Energy 2 / 5"]
        XCTAssertTrue(profileRating.waitForExistence(timeout: timeout))

        app.terminate()
        app.launch()
        try tapVisible(app.buttons["tab_profile"], in: app)
        XCTAssertTrue(profileRating.waitForExistence(timeout: timeout))
    }

    // Cases 06 and 07. Tests pause and recovery without waiting for the 20-minute milestone.
    func testPausedFocusTimeIsSavedAndSessionCanBeResumedAfterRelaunch() throws {
        let app = launchFreshApp()
        let goal = "Learn Python"
        let task = "Learn variables"
        try createFirstGoal(goal, in: app)
        try addTask(task, to: goal, in: app)
        try tapVisible(app.buttons["Start focus: \(task)"], in: app)
        try tapVisible(app.buttons["Start focusing"], in: app)

        let finish = app.buttons["Finish session"]
        let canFinish = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: finish)
        XCTAssertEqual(XCTWaiter.wait(for: [canFinish], timeout: timeout), .completed)
        try tapVisible(app.buttons["Pause"], in: app)
        let pausedTime = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label ENDSWITH %@", "Focused time ", ", paused"
        )).firstMatch
        XCTAssertTrue(pausedTime.waitForExistence(timeout: timeout))
        let timeLabel = pausedTime.label
        let advancedWhilePaused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", timeLabel), object: pausedTime)
        advancedWhilePaused.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [advancedWhilePaused], timeout: 2), .completed)
        let elapsed = timeLabel.replacingOccurrences(of: "Focused time ", with: "")
            .replacingOccurrences(of: ", paused", with: "")

        app.terminate()
        app.launch()
        try tapVisible(app.buttons["tab_sessions"], in: app)
        XCTAssertTrue(app.staticTexts["UNFINISHED · \(elapsed) FOCUSED"].waitForExistence(timeout: timeout))
        try tapVisible(app.buttons["Resume session: \(task)"], in: app)
        try tapVisible(finish, in: app)
        XCTAssertTrue(app.staticTexts["Nice work. Session saved."].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts[task].exists)

        app.terminate()
        app.launch()
        try tapVisible(app.buttons["tab_sessions"], in: app)
        XCTAssertTrue(app.buttons[goal].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.buttons["Resume session: \(task)"].exists)
    }

    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["EMBER_UI_TEST_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    private func createFirstGoal(_ goal: String, in app: XCUIApplication) throws {
        try tapVisible(app.buttons["Start my learning setup"], in: app)
        try enterGoal(goal, in: app)
        try finishSetup(in: app)
    }

    private func enterGoal(_ goal: String, in app: XCUIApplication) throws {
        let field = try textInput("Learning goal name", in: app)
        try tapVisible(field, in: app)
        field.typeText(goal)
        // Continuing commits the typed goal, even before it has been added to the draft list.
        try tapVisible(app.buttons["Continue to Circadian Energy"], in: app)
    }

    private func finishSetup(in app: XCUIApplication) throws {
        try tapVisible(app.buttons["Continue to Plan Blueprint"], in: app)
        try tapVisible(app.buttons["Start Learning"], in: app)
    }

    private func addTask(_ task: String, to goal: String, in app: XCUIApplication) throws {
        try tapVisible(app.buttons[goal], in: app)
        try tapVisible(app.buttons["Add a task"], in: app)
        let field = try textInput("What's one small step?", in: app)
        try tapVisible(field, in: app)
        field.typeText(task + "\n")
        try tapVisible(app.buttons["Done"], in: app)
    }

    private func textInput(_ name: String, in app: XCUIApplication) throws -> XCUIElement {
        let input = app.descendants(matching: .any).matching(NSPredicate(
            format: "(elementType == %d OR elementType == %d) AND (label == %@ OR placeholderValue == %@)",
            XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue, name, name
        )).firstMatch
        return try XCTUnwrap(input.waitForExistence(timeout: timeout) ? input : nil, "Missing input: \(name)")
    }

    private func tapVisible(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing \(element)", file: file, line: line)
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<4 where !element.isHittable && scrollView.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Cannot tap \(element)", file: file, line: line)
        element.tap()
    }
}
