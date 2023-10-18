// whatdidUITests?

import XCTest
@testable import Whatdid

class GoalsTest: AppUITestBase {

    func testNoGoals() {
        group("ptn") {
            clickStatusMenu()
            let ptnGoals = wait(for: .ptn).groups["Goals for today"]
            wait(
                until: {ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title})},
                equals: [])
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("no goals for today") {
            clickStatusMenu(with: .option)
            let goalsReport = wait(for: .dailyEnd).groups["Today's Goals"]
            wait(
                until: {goalsReport.staticTexts.allElementsBoundByIndex.map({$0.stringValue})},
                equals: ["No goals for today."])
            XCTAssertEqual([], goalsReport.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
        group("no goals in past month") {
            let reportWindow = find(.dailyEnd)
            reportWindow.popUpButtons["today"].click()
            reportWindow.menuItems["custom"].click()
            
            let dateRangePopover = reportWindow.popovers.firstMatch
            wait(for: "custom picker to load", until: { dateRangePopover.disclosureTriangles["toggle_endpoint_pickers"].isVisible })
            dateRangePopover.disclosureTriangles["toggle_endpoint_pickers"].click()
            dateRangePopover.datePickers["start_date_picker"].typeIntoDatePicker(month: 11)
            dateRangePopover.buttons["apply_range_button"].click()
            
            let goalsReport = reportWindow.groups["Today's Goals"]
            wait(
                until: {goalsReport.staticTexts.allElementsBoundByIndex.map({$0.stringValue})},
                equals: ["No goals for this date range."])
            XCTAssertEqual([], goalsReport.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            clickStatusMenu()
        }
        group("goals prompt") {
            let goals = openMorningGoals()
            group("validate initial") {
                wait(
                    until: {goals.textFields.allElementsBoundByIndex.map({$0.stringValue})},
                    equals: [""])
                XCTAssertEqual("Dismiss without setting goals", goals.buttons.allElementsBoundByIndex.last?.title)
            }
        }
    }
    
    /// Test of adding and removing a single goal.
    /// We want to make sure that there's always a blank field, and that the Save/Dismiss button updates correctly.
    func testEditingOnlyGoal() {
        let goals = openMorningGoals()
        group("start typing") {
            goals.textFields.element(boundBy: 0).typeText("first attempt")
            XCTAssertEqual(1, goals.textFields.count)
            XCTAssertEqual("Save", goals.buttons.allElementsBoundByIndex.last?.title)
        }
        group("delete text via trash icon") {
            goals.buttons.element(boundBy: 0).click()
            XCTAssertEqual([""], goals.textFields.allElementsBoundByIndex.map({$0.stringValue}))
            XCTAssertEqual("Dismiss without setting goals", goals.buttons.allElementsBoundByIndex.last?.title)
        }
        group("type some more") {
            goals.textFields.element(boundBy: 0).typeText("second attempt")
            XCTAssertEqual(1, goals.textFields.count)
            XCTAssertEqual("Save", goals.buttons.allElementsBoundByIndex.last?.title)
        }
        group("delete text via command-a") {
            let field = goals.textFields.element(boundBy: 0)
            field.typeKey("a", modifierFlags: .command)
            field.typeKey(.delete)
            XCTAssertEqual([""], goals.textFields.allElementsBoundByIndex.map({$0.stringValue}))
            XCTAssertEqual("Dismiss without setting goals", goals.buttons.allElementsBoundByIndex.last?.title)
        }
        group("enter a goal and then delete it") {
            goals.textFields.element(boundBy: 0).typeText("third attempt\r")
            XCTAssertEqual(["third attempt", ""], goals.textFields.allElementsBoundByIndex.map({$0.stringValue}))
            XCTAssertEqual("Save", goals.buttons.allElementsBoundByIndex.last?.title)

            goals.buttons.element(boundBy: 0).click()
            pauseToLetStabilize() // not sure why, but seems to be needed
            XCTAssertEqual([""], goals.textFields.allElementsBoundByIndex.map({$0.stringValue}))
            XCTAssertEqual("Dismiss without setting goals", goals.buttons.allElementsBoundByIndex.last?.title)
        }
    }
    
    func testCommandEnter() {
        let goals = openMorningGoals()
        
        group("first goal") {
            goals.textFields.element(boundBy: 0).typeText("first\r")
            XCTAssertEqual(2, goals.textFields.count)
            XCTAssertEqual("Save", goals.buttons.allElementsBoundByIndex.last?.title)
        }
        group("second goal") {
            goals.textFields.element(boundBy: 1).typeText("second")
            XCTAssertEqual(2, goals.textFields.count)
            XCTAssertEqual("Save", goals.buttons.allElementsBoundByIndex.last?.title)
            goals.typeKey(.enter, modifierFlags: .command)
        }
        group("confirm goals closed") {
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        group("goals are in PTN") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            let ptnGoals = openWindow!.groups["Goals for today"]
            XCTAssertEqual(["first", "second"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([false, false], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.value as? Bool}))
        }
    }
    
    /// Multiple goals, and rm'ing them as well.
    func testEditingMultipleGoals() {
        let goals = openMorningGoals()
        func lookForGoals(_ expected: String...) {
            wait(
                for: "expected goals",
                timeout: 10,
                until: {
                    let snapshot: XCUIElementSnapshot
                    do {
                        snapshot = try goals.snapshot()
                    } catch {
                        log("error while grabbing snapshot: \(error)")
                        return false
                    }
                    let textFields = snapshot.children.filter {$0.elementType == .textField}
                    return textFields.map({$0.value as? String}) == expected
                })
        }
        group("type some entries") {
            goals.typeText("day 1 goal 1\r")
            goals.typeText("delete-me a\r")
            goals.typeText("delete-me b\r")
            goals.typeText("delete-me c\r")
            goals.typeText("day 1 goal 2\r")
            // Expect the 5 above, plus the empty one at the end
            lookForGoals("day 1 goal 1", "delete-me a", "delete-me b", "delete-me c", "day 1 goal 2", "")
        }
        group("delete middle entries") {
            group("delete-me a") {
                goals.textFields.element(boundBy: 1).deleteText(andReplaceWith: "") // "delete-me a"
                // we haven't finished editing yet, so a's field is still there, as a blank text
                lookForGoals("day 1 goal 1", "", "delete-me b", "delete-me c", "day 1 goal 2", "")
            }
            group("click on b") {
                // grab focus on "delete-me b", which should cause a to delete. b should keep its focus
                goals.textFields.element(boundBy: 2).click()
                lookForGoals("day 1 goal 1", "delete-me b", "delete-me c", "day 1 goal 2", "")
                XCTAssertEqual(["delete-me b"], goals.textFields.allElementsBoundByIndex.filter({$0.hasFocus}).map({$0.stringValue}))
            }
            group("delete-me b") {
                goals.deleteText(andReplaceWith: "\r")
                lookForGoals("day 1 goal 1", "delete-me c", "day 1 goal 2", "")
            }
            group("delete-me c") {
                // a and b are both gone now, so c is at index 1 (with "day 1 goal 1" at 0)
                goals.buttons.element(boundBy: 1).click(using: .frame())
                lookForGoals("day 1 goal 1", "day 1 goal 2", "")
            }
        }
        group("save") {
            goals.buttons.allElementsBoundByIndex.last?.click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        group("goals are in PTN") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            let ptnGoals = openWindow!.groups["Goals for today"]
            XCTAssertEqual(["day 1 goal 1", "day 1 goal 2"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([false, false], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.value as? Bool}))
        }
    }
    
    /// Test how goals work in the PTN.
    /// Note: We test the PTN's goals view more extensively in ComponentUITests.testGoalsView (in terms of layout, adding goals, etc).
    func testGoalsInPtn() {
        let goals = openMorningGoals()
        group("setup") {
            goals.typeText("day 1 goal 1\r")
            goals.typeText("day 1 goal 2\r")
            goals.buttons.allElementsBoundByIndex.last?.click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        let ptnGoals = group("open ptn") {() -> XCUIElement in
            clickStatusMenu()
            return wait(for: .ptn)
        }
        group("complete one goal") {
            ptnGoals.checkBoxes.element(boundBy: 1).click(using: .frame())
            XCTAssertEqual(["day 1 goal 1", "day 1 goal 2"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            wait(for: "goal to complete", until: {
                ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}) == ["day 1 goal 1", "day 1 goal 2"]
            })
        }
        group("dismiss the window") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("bring window back and confirm goal still selected") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertEqual(["day 1 goal 1", "day 1 goal 2"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([false, true], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.value as? Bool}))
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
    }
    
    func testGoalsInPtnLayout() {
        let goalsLabelWidthFresh = group("open ptn") {() -> CGFloat in
            let ptn = openPtn().window
            let goalsBar = findGoalsBar(within: ptn)
            return goalsBar.staticTexts["Goals"].frame.width
        }
        let goalsLabelWidthAfterAdding = group("add goals") {() -> CGFloat in
            let goalsBar = findGoalsBar(within: find(.ptn))
            goalsBar.buttons["Add new goal"].click()
            goalsBar.children(matching: .textField).element.typeText(
                "the quick brown fox jumped over the lazy dog "
                    + "the quick brown fox jumped over the\r")
            goalsBar.buttons["Add new goal"].click()
            goalsBar.children(matching: .textField).element.typeText("a\r")
            return goalsBar.staticTexts["Goals"].frame.width
        }
        XCTAssertClose(goalsLabelWidthAfterAdding, goalsLabelWidthFresh, within: 2.0)
        print("fresh: \(goalsLabelWidthFresh)")
        print("after adding: \(goalsLabelWidthAfterAdding)")
        let goalsLabelWidthAfterReopening = group("close and re-open ptn") {() -> CGFloat in
            checkForAndDismiss(window: .ptn)
            let ptn = openPtn().window
            let goalsBar = findGoalsBar(within: ptn)
            return goalsBar.staticTexts["Goals"].frame.width
        }
        XCTAssertClose(goalsLabelWidthAfterReopening, goalsLabelWidthFresh, within: 2.0)
    }
    
    func testGoalAddedLaterInDay() {
        let goals = openMorningGoals()
        group("first goal") {
            goals.typeText("goal 1")
            goals.buttons.allElementsBoundByIndex.last?.click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        let goalsBar = group("goal right on border") {() -> XCUIElement in
            setTimeUtc(h: 08, m: 00)
            let ptn = wait(for: .ptn)
            let goalsBar = findGoalsBar(within: ptn)
            goalsBar.buttons["Add new goal"].click()
            goalsBar.children(matching: .textField).element.typeText("goal 2\r")
            return goalsBar
        }
        group("goal right after grace period") {
            setTimeUtc(h: 08, m: 00, s: 01)
            goalsBar.buttons["Add new goal"].click()
            goalsBar.children(matching: .textField).element.typeText("goal 3\r")
        }
        group("validate in ptn") {
            XCTAssertEqual(
                ["goal 1", "goal 2", "goal 3 🔸"],
                goalsBar.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
        group("validate in ptn after it re-opens") {
            checkForAndDismiss(window: .ptn)
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertEqual(
                ["goal 1", "goal 2", "goal 3 🔸"],
                goalsBar.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("validate in daily report") {
            clickStatusMenu(with: .option)
            let dailyReport = wait(for: .dailyEnd)
            XCTAssertEqual(
                ["goal 1", "goal 2", "goal 3 🔸"],
                dailyReport.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
        group("new goal keeps badge after completion") {
            let dailyReport = find(.dailyEnd)
            let goal3 = dailyReport.checkBoxes.element(boundBy: 2)
            XCTAssertEqual("goal 3 🔸", goal3.title)
            goal3.click()
            wait(for: "goal to be selected", until: {goal3.boolValue})
            XCTAssertEqual("goal 3 🔸", goal3.title)
        }
    }
    
    func testGoalsPromptDoesNotActivateApp() {
        group("fast forward to just before the goals") {
            setTimeUtc(h: 06, m: 59)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
        }
        group("open goals while in background") {
            setTimeUtc(h: 07, m: 00, deactivate: true)
            XCTAssertEqual(XCUIApplication.State.runningBackground, app.state)
        }
    }
    
    func testGoalsPromptWithoutHittingEnterOnLastElement() {
        let goals = openMorningGoals()
        group("type text") {
            goals.textFields.element(boundBy: 0).click()
            goals.typeText("day 1 goal 1\r")
            goals.typeText("day 1 goal 2") // no "\r" !
            XCTAssertEqual(["day 1 goal 1", "day 1 goal 2"], goals.textFields.allElementsBoundByIndex.map({$0.stringValue}))
        }
        group("save") {
            goals.buttons.allElementsBoundByIndex.last?.click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        group("verify in ptn") {
            clickStatusMenu()
            let ptnGoals = wait(for: .ptn).groups["Goals for today"]
            XCTAssertEqual(["day 1 goal 1", "day 1 goal 2"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            ptnGoals.checkBoxes.element(boundBy: 1).click()
            XCTAssertEqual([false, true], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.value as? Bool}))
        }
        group("verify daily report") {
            setTimeUtc(h: 20, m: 00)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
            let goalsReport = find(.dailyEnd).groups["Today's Goals"]
            XCTAssertEqual(["Completed 1 goal out of 2."], goalsReport.staticTexts.allElementsBoundByIndex.map({$0.stringValue}))
            XCTAssertEqual(["day 1 goal 1", "day 1 goal 2"], goalsReport.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([false, true], goalsReport.checkBoxes.allElementsBoundByIndex.map({$0.value as? Bool}))
        }
        group("verify historical report") {
            // The date picker is already active, so just tab to its date field
            let window = find(.dailyEnd)
            
            window.popUpButtons["today"].click()
            window.menuItems["custom"].click()
            let dateRangePopover = window.popovers.firstMatch
            wait(for: "custom picker to load", until: { dateRangePopover.disclosureTriangles["toggle_endpoint_pickers"].isVisible })
            dateRangePopover.disclosureTriangles["toggle_endpoint_pickers"].click()
            dateRangePopover.datePickers["start_date_picker"].typeIntoDatePicker(year: 1968)
            dateRangePopover.buttons["apply_range_button"].click()

            let goalsReport = window.groups["Today's Goals"]
            XCTAssertEqual(
                ["Completed 1 goal out of 2.", "(not listing them, because you selected more than one day)"],
                goalsReport.staticTexts.allElementsBoundByIndex.map({$0.stringValue}))
            XCTAssertEqual([], goalsReport.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            clickStatusMenu() // dismiss the gaily goal
        }
    }
    
    func testGoalsOverridePreviousDayGoals() {
        getToGoalsPromptOnDay2()
        group("type and save goal") {
            let goals = find(.morningGoals)
            goals.typeText("my day 2 goal")
            goals.buttons.allElementsBoundByIndex.last?.click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        /// Check that the day 2 goal is there, and day 1's is not
        group("goal is in PTN") {
            clickStatusMenu()
            let ptnGoals = wait(for: .ptn).groups["Goals for today"]
            XCTAssertEqual(["my day 2 goal"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
    }
    
    func testStatusIconToDismissGoalsPromptDontSave() {
        getToGoalsPromptOnDay2()
        group("type a goal") {
            let goals = find(.morningGoals)
            goals.textFields.element(boundBy: 0).click()
            goals.typeText("goal 1")
        }
        group("dismiss via status menu icon") {
            clickStatusMenu()
            XCTAssertNotNil(openWindow)
            openWindow!.sheets["alert"].buttons["Don't Save"].click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        group("open ptn and look at goals") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            let ptnGoals = openWindow!.groups["Goals for today"]
            XCTAssertEqual([], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
    }
    
    func testStatusIconToDismissGoalsPromptDoSave() {
        getToGoalsPromptOnDay2()
        group("type a goal") {
            let goals = find(.morningGoals)
            goals.textFields.element(boundBy: 0).click()
            goals.typeText("goal 2")
        }
        group("save via status menu icon") {
            clickStatusMenu()
            XCTAssertNotNil(openWindow)
            openWindow!.sheets["alert"].buttons["Save"].click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        group("open ptn and look at goals") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            let ptnGoals = openWindow!.groups["Goals for today"]
            XCTAssertEqual(["goal 2"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
    }
    
    func testDismissButtonWithoutEnteringGoals() {
        getToGoalsPromptOnDay2()
        group("dismiss button") {
            let goals = find(.morningGoals)
            XCTAssertEqual("Dismiss without setting goals", goals.buttons.allElementsBoundByIndex.last?.title)
            goals.buttons.allElementsBoundByIndex.last?.click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        group("open ptn and look at goals") {
            clickStatusMenu()
            let ptnWindow = wait(for: .ptn)
            let ptnGoals = ptnWindow.groups["Goals for today"]
            XCTAssertEqual([], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
        group("add a goal") {
            let ptnWindow = find(.ptn)
            // this lets us confirm that the next step also resets the session
            let goalsView = ptnWindow.children(matching: .group).matching(identifier: "Goals for today").element
            XCTAssertTrue(goalsView.exists)
            goalsView.buttons["Add new goal"].click()
            let textField = goalsView.children(matching: .textField).element
            XCTAssertTrue(textField.isVisible)
            textField.typeText("goal again\r")
        }
    }
        
    func testStatusIconWithoutEnteringGoals() {
        getToGoalsPromptOnDay2()
        // don't type a goal
        group("dismiss via status menu icon") {
            clickStatusMenu()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        group("open ptn and look at goals") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            let ptnGoals = openWindow!.groups["Goals for today"]
            XCTAssertEqual([], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
    }
    
    private func openMorningGoals() -> XCUIElement {
        return group("fast-forward to goals prompt") {
            setTimeUtc(h: 07, m: 00)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            return wait(for: .morningGoals)
        }
    }
    
    /// Whether we've double-checked the goals for day 1 in `getToGoalsPromptOnDay2`.
    /// That method sets up goals on day 1, and then fast-forwards to day 2. We want to validate that the goals actually got set, since tests
    /// will check that they don't carry over (and we don't want a false negative due to two bugs, one that fails to reset the goals, and the other
    /// that fails to set them in the first place).
    /// But, that validation takes time, and we only need it once per run of this class -- just to validate that it's working correctly at all.
    /// If it works one time, we can trust it to work always.
    private var haveDoubleCheckedDay1Goals = false
    
    /// Gets us to a goals prompt on day 2, where day 1 had some goals.
    /// This is useful for validating that the old goals went away.
    private func getToGoalsPromptOnDay2() {
        group("fast-forward to goals") {
            let day1 = openMorningGoals()
            day1.typeText("goal on day 1\r")
            day1.buttons.allElementsBoundByIndex.last?.click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        if !haveDoubleCheckedDay1Goals {
            group("goal is in PTN") {
                clickStatusMenu()
                let ptnGoals = wait(for: .ptn).groups["Goals for today"]
                XCTAssertEqual(["goal on day 1"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
                clickStatusMenu()
            }
            haveDoubleCheckedDay1Goals = true
        }
        group("fast-forward to goals on day 2") {
            setTimeUtc(d: 1, h: 07, m: 00)
            let _ = wait(for: .dailyEnd)
            clickStatusMenu()
            handleLongSessionPrompt(on: .ptn, .startNewSession)
        }
    }
    
    private func findGoalsBar(within element: XCUIElement) -> XCUIElement {
        return element.children(matching: .group).matching(identifier: "Goals for today").element
    }

}
