// whatdidUITests?

import XCTest
@testable import whatdid

class PrefsUITest: AppUITestBase {
    func testPreferences() {
        let ptn = openPtn()
        let prefsButton = ptn.window.buttons["Preferences"]
        let prefsSheet = ptn.window.sheets.firstMatch
        prefsButton.click()
        XCTAssertTrue(prefsSheet.isVisible)
        group("About") {
            prefsSheet.tabs["About"].click()
            // Sanity check: just make sure that the text includes "whatdid {version}".
            // Note: we'll need to update this whenever we do a version bump.
            // That seems more explicit and easier to reason about than plumbing the Version class to here
            XCTAssertTrue(prefsSheet.staticTexts["whatdid 0.1"].firstMatch.isVisible)
        }
        group("General") {
            prefsSheet.tabs["General"].click()
            group("Configure global shortcut") {
                group("Record a new global shotcut") {
                    prefsSheet.searchFields["Record Shortcut"].click()
                    ptn.window.typeKey("i", modifierFlags:[.command, .shift])
                }
                group("Close PTN and test new shortcut") {
                    clickStatusMenu()
                    waitForTransition(of: .ptn, toIsVisible: false)
                    pressHotkeyShortcut(keyCode: 34) // 34 is "i"
                    waitForTransition(of: .ptn, toIsVisible: true)
                }
                group("Open preferences back up") {
                    prefsButton.click()
                    XCTAssertTrue(prefsSheet.isVisible)
                }
            }
            group("Set daily report time") {
                group("Set the time") {
                    let timePicker = prefsSheet.datePickers["daily report time"]
                    clickOnHourSegment(of: timePicker)
                    timePicker.typeText("2\t02\t") // last tab is to the AM/PM picker
                    timePicker.typeKey(.downArrow) // PM -> AM
                }
                group("Check for daily report") {
                    clickStatusMenu() // close the PTN and prefs
                    setTimeUtc(h: 0, m: 1)
                    sleepMillis(500) // in case something was going to pop up
                    XCTAssertFalse(isWindowVisible(.ptn))
                    XCTAssertFalse(isWindowVisible(.dailyEnd))
                    setTimeUtc(h: 0, m: 3)
                    waitForTransition(of: .dailyEnd, toIsVisible: true)
                }
                group("Close daily report") {
                    checkForAndDismiss(window: .dailyEnd)
                }
            }
            group("Set snooze-until-tomorrow time") {
                let snoozeOpts = ptn.window.menuButtons["snoozeopts"]
                let snoozeOptions = snoozeOpts.descendants(matching: .menuItem)
                group("Set up") {
                        group("Set time to 6pm on Friday") {
                        XCTAssertFalse(isWindowVisible(.ptn))
                        XCTAssertFalse(isWindowVisible(.dailyEnd))
                        // We're starting on 1/1/1970 at 2:03 am. That's a Thursday.
                        setTimeUtc(d: 1, h: 16, m: 0)
                        handleLongSessionPrompt(on: .ptn, .startNewSession)
                        checkForAndDismiss(window: .dailyEnd)
                        checkForAndDismiss(window: .morningGoals)
                        sleepMillis(500)
                    }
                    group("Open prefs") {
                        clickStatusMenu() // open ptn
                        snoozeOpts.click()
                        let snoozeOptionLabels = snoozeOptions.allElementsBoundByIndex.map { $0.title }
                        XCTAssertEqual(["7:00 pm", "7:30 pm", "8:00 pm", "", "Monday at 9:00 am"], snoozeOptionLabels)
                        prefsButton.click() // once to dismiss the snooze options popup
                        sleepMillis(500)
                        prefsButton.click() // and then to actually click the prefs button
                    }
                }
                group("Set snooze-until-tomorrow") {
                    let timePicker = prefsSheet.datePickers["snooze until tomorrow time"]
                    clickOnHourSegment(of: timePicker)
                    timePicker.typeText("11\t23")
                    prefsSheet.checkBoxes["snooze until tomorrow includes weekends"].click()
                    prefsSheet.buttons["Done"].click()
                    snoozeOpts.click()
                    let snoozeOptionLabels = snoozeOptions.allElementsBoundByIndex.map { $0.title }
                    XCTAssertEqual(["7:00 pm", "7:30 pm", "8:00 pm", "", "tomorrow at 11:23 am"], snoozeOptionLabels)
                }
                group("Open preferences back up") {
                    prefsButton.click() // once to dismiss the snooze options popup
                    sleepMillis(500)
                    prefsButton.click() // and then to actually click the prefs button
                }
            }
        }
        group("Finish preferences") {
            wait(for: "preferences sheet", until: {ptn.window.exists && ptn.window.sheets.count > 0})
            prefsSheet.buttons["Done"].click()
            wait(for: "prefernces sheet", until: {ptn.window.exists && ptn.window.sheets.count == 0})
        }
        group("Quit") {
            prefsButton.click()
            wait(for: "prefernces sheet", until: {ptn.window.exists && ptn.window.sheets.count > 0})
            prefsSheet.buttons["Quit"].click()
            wait(for: "app to exit", until: {app.state == .notRunning})
       }
    }

    func testScheduleUiElements() {
        let ptn = openPtn()
        let prefsButton = ptn.window.buttons["Preferences"]
        let prefsSheet = ptn.window.sheets.firstMatch
        let frequencyText = prefsSheet.textFields["frequency"]
        let frequencyStepper = prefsSheet.steppers["frequency stepper"]
        let jitterText = prefsSheet.textFields["frequency randomness"]
        let jitterStepper = prefsSheet.steppers["frequency randomness stepper"]
            
        group("Setup") {
            prefsButton.click()
            XCTAssertTrue(prefsSheet.isVisible)
            prefsSheet.tabs["General"].click()
            XCTAssertEqual("12", frequencyText.stringValue)
            XCTAssertEqual("2", jitterText.stringValue)
        }
        group("UI elements") {
            group("Frequency max is 120") {
                frequencyText.deleteText(andReplaceWith: "130\r")
                XCTAssertEqual("120", frequencyText.stringValue)

                frequencyStepper.children(matching: .decrementArrow).element.click()
                XCTAssertEqual("119", frequencyText.stringValue)

                frequencyStepper.children(matching: .incrementArrow).element.click()
                XCTAssertEqual("120", frequencyText.stringValue)

                // Make sure the stepper can't go over
                frequencyStepper.children(matching: .incrementArrow).element.click()
                XCTAssertEqual("120", frequencyText.stringValue)

                // Make sure the stepper didn't internally set a state of 121
                frequencyStepper.children(matching: .decrementArrow).element.click()
                XCTAssertEqual("119", frequencyText.stringValue)

                jitterText.deleteText(andReplaceWith: "70\r")
                XCTAssertEqual("59", jitterText.stringValue) // half of 119, rounded down
            }
            group("Frequency min is 5") {
                frequencyText.deleteText(andReplaceWith: "4\r")
                XCTAssertEqual("5", frequencyText.stringValue)
                XCTAssertEqual("2", jitterText.stringValue) // half of 5, rounded down
            }
            group("Jitter stepper") {
                jitterStepper.children(matching: .decrementArrow).firstMatch.click()
                XCTAssertEqual("1", jitterText.stringValue)

                jitterStepper.children(matching: .decrementArrow).firstMatch.click()
                XCTAssertEqual("0", jitterText.stringValue)

                // Make sure the stepper can't go under
                jitterStepper.children(matching: .decrementArrow).firstMatch.click()
                XCTAssertEqual("0", jitterText.stringValue)

                // Make sure the stepper didn't internally set a state of -1
                jitterStepper.children(matching: .incrementArrow).firstMatch.click()
                XCTAssertEqual("1", jitterText.stringValue)
            }
        }
    }
}
