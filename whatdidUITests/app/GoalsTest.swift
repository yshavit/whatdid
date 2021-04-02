// whatdidUITests?

import XCTest
@testable import whatdid

class GoalsTest: AppUITestBase {

    func testNoGoals() {
        group("ptn") {
            clickStatusMenu()
            let ptnGoals = wait(for: .ptn).groups["Goals for today"]
            XCTAssertEqual([], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("daily report") {
            clickStatusMenu(with: .maskAlternate)
            let goalsReport = wait(for: .dailyEnd).groups["Today's Goals"]
            XCTAssertEqual(
                ["No goals for today."],
                goalsReport.staticTexts.allElementsBoundByIndex.map({$0.stringValue}))
            XCTAssertEqual([], goalsReport.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            
            openWindow!.typeKey(.downArrow) // date picker is selected by default, so this goes 1 month earlier
            XCTAssertEqual(
                ["No goals for this time range."],
                goalsReport.staticTexts.allElementsBoundByIndex.map({$0.stringValue}))
            XCTAssertEqual([], goalsReport.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            clickStatusMenu()
        }
        group("goals prompt") {
            let goals = openMorningGoals()
            group("validate initial") {
                XCTAssertEqual([""], goals.textFields.allElementsBoundByIndex.map({$0.stringValue}))
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
    
    /// Multiple goals, and rm'ing them as well.
    func testEditingMultipleGoals() {
        let goals = openMorningGoals()
        group("type some entries") {
            goals.typeText("day 1 goal 1\r")
            goals.typeText("delete-me a\r")
            goals.typeText("delete-me b\r")
            goals.typeText("delete-me c\r")
            goals.typeText("day 1 goal 2\r")
            XCTAssertEqual(6, goals.textFields.count) // the 4 above, plus the empty one at the end
        }
        group("delete middle entries") {
            group("delete-me a") {
                goals.textFields.element(boundBy: 1).deleteText(andReplaceWith: "") // "delete-me a"
                XCTAssertEqual(6, goals.textFields.count) // we haven't finished editing yet, so it's still there
            }
            group("delete-me b") {
                // grab focus on "delete-me b", which should cause a to delete. b should keep its focus
                goals.textFields.element(boundBy: 2).click()
                pauseToLetStabilize()
                XCTAssertEqual(["delete-me b"], goals.textFields.allElementsBoundByIndex.filter({$0.hasFocus}).map({$0.stringValue}))
                goals.deleteText(andReplaceWith: "\r")
            }
            group("delete-me c") {
                pauseToLetStabilize()
                // a and b are both gone now, so c is at index 1 (with "day 1 goal 1" at 0)
                goals.buttons.element(boundBy: 1).click()
            }
            group("final validation") {
                pauseToLetStabilize()
                XCTAssertEqual(
                    ["day 1 goal 1", "day 1 goal 2", ""],
                    goals.textFields.allElementsBoundByIndex.map({$0.stringValue}))
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
            ptnGoals.checkBoxes.element(boundBy: 1).click()
            XCTAssertEqual(["day 1 goal 1", "day 1 goal 2"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([false, true], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.value as? Bool}))
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
    
    func testGoalsPromptDoesNotActivateApp() {
        _ = openMorningGoals(deactivate: true)
        sleep(1) // If it was going to be switch to active, this would be enough time
        XCTAssertEqual(XCUIApplication.State.runningBackground, app.state)
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
            // click on the first element of the dd/mm/yyyy picker, and then tab to the year
            window.datePickers.element.click(using: .frame(xInlay: 0.1))
            window.typeText("\t\t")
            window.typeKey(.downArrow)
            
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
            waitForTransition(of: .ptn, toIsVisible: true)
            let ptnGoals = openWindow!.groups["Goals for today"]
            XCTAssertEqual([], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
        group("add a goal") {
            // this lets us confirm that the next step also resets the session
            let ptnWindow = find(.ptn)
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
    
    private func openMorningGoals(deactivate: Bool = false) -> XCUIElement {
        return group("fast-forward to goals prompt") {
            setTimeUtc(h: 06, m: 59)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            setTimeUtc(h: 07, m: 00, deactivate: deactivate)
            return wait(for: .morningGoals)
        }
    }
    
    /// Gets us to a goals prompt on day 2, where day 1 had some goals.
    /// This is useful for validating that the old goals went away.
    private func getToGoalsPromptOnDay2() {
        group("fast-forward to goals") {
            let day1 = openMorningGoals()
            day1.typeText("goal on day 1\r")
            day1.buttons.allElementsBoundByIndex.last?.click()
            waitForTransition(of: .morningGoals, toIsVisible: false)
        }
        group("goal is in PTN") {
            clickStatusMenu()
            let ptnGoals = wait(for: .ptn).groups["Goals for today"]
            XCTAssertEqual(["goal on day 1"], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([false], ptnGoals.checkBoxes.allElementsBoundByIndex.map({$0.value as? Bool}))
            clickStatusMenu()
        }
        group("fast-forward to goals on day 2") {
            setTimeUtc(d: 1, h: 06, m: 59)
            let _ = wait(for: .dailyEnd)
            clickStatusMenu()
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            setTimeUtc(d: 1, h: 07, m: 00)
        }
    }

}
