// whatdidUITests?

import XCTest
@testable import whatdid

class ScheduleTest: AppUITestBase {
    
    func testBasicSchedule() {
        // Default is 12 minutes +/- 2.
        setTimeUtc(h: 0, m: 9) // 02:09; too soon for the popup
        pauseToLetStabilize()
        assertThat(window: .ptn, isVisible: false)
        setTimeUtc(h: 0, m: 15, deactivate: true) // 02:15; enough time for the popup
        waitForTransition(of: .ptn, toIsVisible: true)
        XCTAssertEqual(XCUIApplication.State.runningBackground, app.state)
    }
    
    func testWritingAnEntryResetsTimer() {
        group("Wait 9 minutes") {
            setTimeUtc(h: 0, m: 9)
            pauseToLetStabilize()
            assertThat(window: .ptn, isVisible: false)
        }
        group("Manually open PTN and add entry") {
            clickStatusMenu()
            let ptn = wait(for: .ptn)
            ptn.typeText("Project\r")
            ptn.typeText("Task\r")
            ptn.typeText("Notes\r")
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Wait another 9 minutes") {
            // If the previous group didn't reset the timer, we'd have gotten a scheduled PTN by now,
            // since it'd be 18 minutes since the last PTN (so more than the 12 + 2 max schedule time).
            // We expect that the previous group *did* reset the schedule, though, so we won't get one.
            setTimeUtc(h: 0, m: 18)
            pauseToLetStabilize()
            assertThat(window: .ptn, isVisible: false)
        }
        group("Open and close PTN without adding entry") {
            group("Open and close PTN") {
                clickStatusMenu()
                checkForAndDismiss(window: .ptn)
            }
            group("Wait a final 9 minutes") {
                // Opening and closing the PTN (without saving an entry) does *not* reset the clock,
                // so by now we've waited 27 - 9 = 18 minutes since the last reset (which was when we
                // manually opened the PTN to add an entry). We expect a popup.
                setTimeUtc(h: 0, m: 27)
                waitForTransition(of: .ptn, toIsVisible: true)
            }
        }
    }
    
    /// For this test, note that the mocked local time zone is UTC+0200
    func testHeaderAndSnoozeOptionLabels() {
        let (ptn, button) = openPtnAndGetButton()
        group("Initial state") {
            // It's now 1970-01-02 16:31:00 UTC, which is 6:31 pm. Check that the default snooze option is to 7:00.
            XCTAssertEqual("Snooze until 2:30 am", button.title.trimmingCharacters(in: .whitespaces))
            XCTAssertTrue(button.isEnabled)
            XCTAssertEqual(
                "What have you been working on for the last 0m (since 2:00 am)?",
                ptn.staticTexts["durationheader"].stringValue)
        }
        group("Wait until right before the update") {
            setTimeUtc(h:0, m: 24, s: 59)
            // Unchanged
            XCTAssertEqual("Snooze until 2:30 am", button.title.trimmingCharacters(in: .whitespaces))
            XCTAssertTrue(button.isEnabled)
            XCTAssertEqual(0, ptn.activityIndicators.count) // spinner
            XCTAssertEqual(
                "What have you been working on for the last 25m (since 2:00 am)?",
                ptn.staticTexts["durationheader"].stringValue)
        }
        group("Update is in progress") {
            setTimeUtc(h: 0, m: 25, s: 00)
            // Text is unchanged, but button is disabled
            XCTAssertEqual("Snooze until 2:30 am", button.title.trimmingCharacters(in: .whitespaces))
            XCTAssertFalse(button.isEnabled)
            wait(for: "spinner", timeout: 5, until: {ptn.activityIndicators.count == 1})
        }
        group("Update is done") {
            setTimeUtc(h: 0, m: 25, s: 01)
            // Update complete
            XCTAssertEqual("Snooze until 3:00 am", button.title.trimmingCharacters(in: .whitespaces))
            XCTAssertTrue(button.isEnabled)
            wait(for: "spinner", timeout: 5, until: {ptn.activityIndicators.count == 0})
        }
        group("Check snooze options") {
            // It's currently 6:55 pm on Friday, Jan 2. So "tomorrow" is actually Monday.
            // The default option is 7:30 pm, and the extra options start at 8:00 pm.
            let snoozeOptions = openSnoozeOptions(on: ptn)
            let snoozeOptionLabels = snoozeOptions.allElementsBoundByIndex.map { $0.title }
            XCTAssertEqual(["3:30 am", "4:00 am", "4:30 am", "", "9:00 am"], snoozeOptionLabels)
        }
        group("Check weekend snooze-until-tomorrow option") {
            // Jan 1 1970 was a Thursday, so let's go to Friday. Then, the "tomorrow" state
            // should be until Monday.
            group("Fast-forward to after daily report") {
                setTimeUtc(d: 1, h: 18, m: 0)
                handleLongSessionPrompt(on: .ptn, .startNewSession)
                checkForAndDismiss(window: .dailyEnd)
                checkForAndDismiss(window: .morningGoals)
                clickStatusMenu()
            }
            group("Check options") {
                let snoozeOptions = openSnoozeOptions(on: ptn)
                let snoozeOptionLabels = snoozeOptions.allElementsBoundByIndex.map { $0.title }
                XCTAssertEqual(["9:00 pm", "9:30 pm", "10:00 pm", "", "Monday at 9:00 am"], snoozeOptionLabels)
            }
            group("Snooze until Monday") {
                ptn.menuItems["Monday at 9:00 am"].click()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Until Monday at 8:59am") {
                // There shouldn't be any popups. So fast-forward until then, wait a second, and confirm nothing happens.
                setTimeUtc(d: 4, h: 06, m: 59)
                sleepMillis(1000)
                XCTAssertNil(openWindow)
            }
            group("Wait one more minute") {
                setTimeUtc(d: 4, h: 07, m: 00)
                // Note: the PTN gets scheduled first, so will show up before the morning goals.
                waitForTransition(of: .ptn, toIsVisible: true)
            }
        }
    }
    
    func testSnoozeDefaultOption() {
        let (_, button) = openPtnAndGetButton()
        // It's 02:00 now, the snooze is until 2:30.
        // Trim whitespace, since we put some in so it aligns well with the snoozeopts button
        XCTAssertEqual("Snooze until 2:30 am", button.title.trimmingCharacters(in: .whitespaces))
        button.click(using: .frame())
        waitForTransition(of: .ptn, toIsVisible: false)
        
        // To go 02:29+0200, and the PTN should still be hidden
        setTimeUtc(m: 29)
        assertThat(window: .ptn, isVisible: false)

        // But one more minute, and it is visible again
        setTimeUtc(m: 30)
        waitForTransition(of: .ptn, toIsVisible: true)
    }
    
    func testSnoozeExtraOptions() {
        let (ptn, _) = openPtnAndGetButton()
        let snoozeOptions = openSnoozeOptions(on: ptn)
        let snoozeOptionLabels = snoozeOptions.allElementsBoundByIndex.map { $0.title }
        XCTAssertEqual(["3:00 am", "3:30 am", "4:00 am", "", "9:00 am"], snoozeOptionLabels)
        ptn.menuItems["4:00 am"].click()
        
        // To go 03:29+0200, and the PTN should still be hidden
        setTimeUtc(h: 1, m: 59)
        waitForTransition(of: .ptn, toIsVisible: false)

        // But one more minute, and it is visible again
        setTimeUtc(h: 2, m: 00)
        waitForTransition(of: .ptn, toIsVisible: true)
    }
    
    func testUnsnoozeBeforePtn() {
        let (_, button) = openPtnAndGetButton()
        group("Start snoozing") {
            XCTAssertEqual("Snooze until 2:30 am", button.title.trimmingCharacters(in: .whitespaces))
            button.click(using: .frame()) // open up the unsnooze)
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Unsnooze a minute later") {
            setTimeUtc(m: 1)
            assertThat(window: .ptn, isVisible: false) // sanity check that we're still closed
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            
            wait(for: "snoozebutton to exist", until: {button.isVisible})
            button.click(using: .frame()) // open up the unsnooze
            button.buttons["Unsnooze"].click()
            
            assertThat(window: .ptn, isVisible: true) // unsnoozing doesn't close the window
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Fast-forward to after the PTN will pop up") {
            setTimeUtc(m: 15)
            waitForTransition(of: .ptn, toIsVisible: true)
        }
    }
    
    func testUnsnoozeAfterPtnCloseWithoutEntry() {
        let (_, button) = openPtnAndGetButton()
        group("Start snoozing until 2:30") {
            XCTAssertEqual("Snooze until 2:30 am", button.title.trimmingCharacters(in: .whitespaces))
            button.click(using: .frame()) // open up the unsnooze)
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Unsnooze at 2:29") {
            setTimeUtc(m: 29)
            assertThat(window: .ptn, isVisible: false) // still snoozing
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            
            wait(for: "snoozebutton to exist", until: {button.exists})
            button.click(using: .frame()) // open up the unsnooze) // open up the unsnooze
            button.buttons["Unsnooze"].click()
        }
        group("Close PTN without adding entry") {
            sleep(1)
            assertThat(window: .ptn, isVisible: true)
            clickStatusMenu() // close the window
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("No popup within 9 minutes of unsnooze") {
            setTimeUtc(m: 38)
            sleep(1)
            XCTAssertNil(openWindow)
        }
        group("Has popup within 14 minutes of unsnooze") {
            setTimeUtc(m: 43, s: 1) // +1 sec to avoid any fencepost bugs; we don't care about this level of precision
            waitForTransition(of: .ptn, toIsVisible: true)
        }
    }
    
    func testUnsnoozeAfterPtnCloseWithEntry() {
        let (ptn, button) = openPtnAndGetButton()
        group("Start snoozing until 2:30") {
            XCTAssertEqual("Snooze until 2:30 am", button.title.trimmingCharacters(in: .whitespaces))
            button.click(using: .frame()) // open up the unsnooze)
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Unsnooze at 2:29") {
            setTimeUtc(m: 29)
            assertThat(window: .ptn, isVisible: false) // still snoozing
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            
            wait(for: "snoozebutton to be visible", until: {button.isVisible})
            button.click(using: .frame()) // open up the unsnooze
            button.buttons["Unsnooze"].click()
        }
        group("Add an entry") {
            ptn.typeText("my project\r")
            ptn.typeText("my task\r")
            ptn.typeText("my notes\r")
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("No popup within 9 minutes of unsnooze") {
            setTimeUtc(m: 38)
            sleep(1)
            XCTAssertNil(openWindow)
        }
        group("Has popup within 14 minutes of unsnooze") {
            setTimeUtc(m: 43, s: 1) // +1 sec to avoid any fencepost bugs; we don't care about this level of precision
            waitForTransition(of: .ptn, toIsVisible: true)
        }
    }
    
    /// PTN-DayEnd contention, with the PTN coming first
    func testContentionPtnFirst() {
        group("fast-forward to day start") {
            // This is just to take the day-start popup out of the picture
            setTimeUtc(h: 7)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            checkForAndDismiss(window: .morningGoals) // since we crossed 9:00am
        }
        group("fast-forward to just before daily report, keep PTN open") {
            setTimeUtc(h: 15, m: 59)
            handleLongSessionPrompt(on: .ptn, .continueWithCurrentSession)
        }
        group("wait one more minute") {
            setTimeUtc(h: 16, m: 00)
            sleep(1) // to make sure nothing happens before we check for the PTN in the next step
        }
        group("daily report pops up after ptn") {
            checkForAndDismiss(window: .ptn)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
        }
    }
    
    /// PTN-DayEnd contention, with the daily report coming first
    /// This also tests the daily report opening uncontested
    func testContentionDailyReportFirst() {
        group("fast-forward to just before daily report") {
            setTimeUtc(h: 15, m: 59)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            checkForAndDismiss(window: .morningGoals) // since we crossed 9:00am
        }
        group("daily report one minute later") {
            setTimeUtc(h: 16, m: 00)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
        }
        group("wait 15 more minutes") {
            setTimeUtc(h: 16, m: 15)
            sleep(1) // to make sure nothing happens before we check for the daily report in the next step
        }
        group("daily report pops up after ptn") {
            checkForAndDismiss(window: .dailyEnd)
            waitForTransition(of: .ptn, toIsVisible: true)
        }
    }
    
    func testDailyReportWithContentionWithPtn() {
        group("A day later, just before the daily report") {
            setTimeUtc(d: 1, h: 16, m: 29)
            waitForTransition(of: .ptn, toIsVisible: true)
        }
        group("Now at the daily report") {
            setTimeUtc(d: 1, h: 16, m: 31)
            assertThat(window: .dailyEnd, isVisible: false)
            handleLongSessionPrompt(on: .ptn, .continueWithCurrentSession)
        }
        group("Enter a PTN entry") {
            type(into: app, entry("my project", "my task", "my notes"))
            waitForTransition(of: .ptn, toIsVisible: false)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
            add(XCTAttachment(screenshot: XCUIScreen.main.screenshot()))
        }
        group("Close the daily report") {
            clickStatusMenu() // close the daily report
            waitForTransition(of: .dailyEnd, toIsVisible: false)
            checkForAndDismiss(window: .morningGoals) // since we went past the 1d 09:00 border
            // Also wait a second, so that we can be sure it didn't pop back open (GH #72)
            Thread.sleep(forTimeInterval: 1)
            assertThat(window: .dailyEnd, isVisible: false)
            assertThat(window: .ptn, isVisible: false)
        }
    }
    
    // For the no-jitter variant, we'll try 6 times. If there's 1 minute of jitter, the chance of any
    // one iteration succeeding is 50%, and the chance of all 10 succeeding is 0.5^6 = 1.56%.
    // If there's 2 minutes of jitter, the chance of any one iteration succeeding (ie, randomly having
    // no jitter) is 30%, and the chance of all 10 succeeding is 0.0017%.
    func testCustomScheduleNoJitter() {
        let ptn = openPtn()
        let prefsButton = ptn.window.buttons["Preferences"]
        let prefsSheet = ptn.window.sheets.firstMatch
        let frequencyText = prefsSheet.textFields["frequency"]
        let jitterText = prefsSheet.textFields["frequency randomness"]
        
        group("Setup") {
            group("Open prefs") {
                prefsButton.click()
                XCTAssertTrue(prefsSheet.isVisible)
                prefsSheet.tabs["General"].click()
            }
            group("Set schedule: 10m±0m") {
                frequencyText.deleteText(andReplaceWith: "10\r")
                jitterText.deleteText(andReplaceWith: "0\r")
                XCTAssertEqual("10", frequencyText.stringValue)
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
        }
        
        var minutesSinceUtc = 0
        for i in 0..<6 {
            group("Iteration \(i)") {
                minutesSinceUtc += 10
                let secondsSinceUtc = minutesSinceUtc * 60
                setTimeUtc(s: secondsSinceUtc - 1)
                pauseToLetStabilize()
                XCTAssertNil(openWindow)
                setTimeUtc(s: secondsSinceUtc)
                checkForAndDismiss(window: .ptn)
            }
        }
    }
    
    /// Because the jitter is random, we're going to take a statistical approach to these.
    ///
    /// For the with-jitter variant, we'll try up to 20 times with 5 minutes of jitter, which means
    /// jitter is anywhere from -5 to +5: 11 values. The chance of randomly hitting jitter > 0 is 45.45%
    /// and the chance of doing that 20 times in a row is 0.000014%; so there's a very small chance
    /// of never hitting jitter >= 0. Similarly, there's a very small chance of never hitting jitter less than zero.
    /// So, we just run the 20 loops until we find both one jitter above 0 and one below it; as long as we
    /// have those two values, we can be reasonably certain there's some randomness.
    func testCustomScheduleWithJitter() {
        let ptn = openPtn()
        let prefsButton = ptn.window.buttons["Preferences"]
        let prefsSheet = ptn.window.sheets.firstMatch
        let frequencyText = prefsSheet.textFields["frequency"]
        let jitterText = prefsSheet.textFields["frequency randomness"]
        
        group("Setup") {
            group("Open prefs") {
                prefsButton.click()
                XCTAssertTrue(prefsSheet.isVisible)
                prefsSheet.tabs["General"].click()
            }
            group("Set schedule: 10m±0m") {
                frequencyText.deleteText(andReplaceWith: "10\r")
                jitterText.deleteText(andReplaceWith: "5\r")
                XCTAssertEqual("10", frequencyText.stringValue)
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
        }
        var minutesSinceUtc = 0
        var foundJitterBelowZero = false
        var foundJitterAboveZero = false
        for i in 0..<20 {
            // Returns whether the jitter was < 0. See doc on this method for why we care.
            let foundPtn = group("Iteration \(i)") {() -> Bool in
                minutesSinceUtc += 10
                let secondsSinceUtc = minutesSinceUtc * 60
                setTimeUtc(s: secondsSinceUtc - 1)
                pauseToLetStabilize()
                if let window = openWindow {
                    XCTAssertEqual(WindowType.ptn.windowTitle, window.title)
                    log("Found PTN")
                    return true
                } else {
                    // The random jitter was >= 0 minutes. Fast forward another 10 minutes so we can
                    // be sure to get the PTN, and then close it and try again.
                    minutesSinceUtc += 10
                    setTimeUtc(m: minutesSinceUtc)
                    checkForAndDismiss(window: .ptn)
                    return false
                }
            }
            log("Was jitter below zero? => \(foundPtn)")
            if foundPtn {
                foundJitterBelowZero = true
            } else {
                foundJitterAboveZero = true
            }
            if foundJitterBelowZero && foundJitterAboveZero {
                break // we've seen one of each, so we're done!
            }
        }
    }
    
    /// Opens the PTN and returns a `(ptn, snoozeButton)` pair
    private func openPtnAndGetButton() -> (XCUIElement, XCUIElement) {
        group("open PTN") {() -> (XCUIElement, XCUIElement) in
            clickStatusMenu()
            let ptn = wait(for: .ptn)
            return (ptn, ptn.buttons["snoozebutton"])
        }
    }
    
    /// Opens the snooze options, and returns an XCUIElementQuery for its sub-items
    func openSnoozeOptions(on ptn: XCUIElement) -> XCUIElementQuery {
        let snoozeOptsButton = ptn.menuButtons["snoozeopts"] // note: menuButtons != buttons!
        snoozeOptsButton.click()
        return snoozeOptsButton.descendants(matching: .menuItem)
    }
}
