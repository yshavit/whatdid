// whatdidUITests?

import XCTest
@testable import whatdid

class PtnViewControllerTest: UITestBase {
    private static let SOME_TIME = Date()
    
    func openPtn(andThen afterAction: (XCUIElement) -> () = {_ in }) -> Ptn {
        return group("open PTN") {
            switch openWindow {
            case .none:
                clickStatusMenu()
            case let .some(w) where w.title == WindowType.ptn.windowTitle:
                break
            case let .some(w) where WindowType.allCases.map({$0.windowTitle}).contains(w.title):
                clickStatusMenu()
                wait(for: "window to close", until: {openWindow == nil})
                sleepMillis(500)
                clickStatusMenu()
            case let .some(w):
                XCTFail("unexpected window: \(w.title)")
            }
            waitForTransition(of: .ptn, toIsVisible: true)
            let ptn = findPtn()
            afterAction(ptn.window)
            return ptn
        }
    }
    
    func findPtn() -> Ptn {
        let ptn = app.windows[WindowType.ptn.windowTitle]
        return Ptn(
            window: ptn,
            pcombo: AutocompleteFieldHelper(element: ptn.comboBoxes["pcombo"]),
            tcombo: AutocompleteFieldHelper(element: ptn.comboBoxes["tcombo"]))
    }
    
    /// Clicks on the leftmost element of the date picker, to select its "hours" segment. Otherwise, the system can click
    /// on anywhere in it, and might choose e.g. the AM/PM part.
    func clickOnHourSegment(of datePicker: XCUIElement) {
        datePicker.click(using: .frame(xInlay: 1.0/6))
    }
    
    func testLongSessionPrompt() {
        group("Long session while PTN is open") {
            clickStatusMenu()
            setTimeUtc(d: 0, h: 5, m: 59)
            setTimeUtc(d: 0, h: 6, m: 00)
            handleLongSessionPrompt(on: .ptn, .doNothing)
        }
        group("New session resets the time") {
            group("Select option to start new session") {
                handleLongSessionPrompt(on: .ptn, .startNewSession)
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Create an entry") {
                setTimeUtc(d: 0, h: 6, m: 5)
                let ptn = openPtn()
                type(into: ptn.window, entry("p1", "t2", "n3"))
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Verify entry") {
                let ptn = openPtn()
                let entries = FlatEntry.deserialize(from: ptn.entriesHook.stringValue)
                XCTAssertEqual(
                    [FlatEntry(from: date(h: 6, m: 00), to: date(h: 6, m: 05), project: "p1", task: "t2", notes: "n3")],
                    entries)
                ptn.entriesHook.deleteText(andReplaceWith: "\r")
            }
        }
        group("Long session while PTN is open (again)") {
            setTimeUtc(d: 0, h: 06, m: 15)
            waitForTransition(of: .ptn, toIsVisible: true)
            setTimeUtc(d: 0, h: 12, m: 15)
        }
        group("Continuing session keeps the time") {
            group("Select option to continue session") {
                handleLongSessionPrompt(on: .ptn, .continueWithCurrentSession)
            }
            group("Create an entry") {
                let ptn = findPtn()
                ptn.pcombo.textField.deleteText() // since it'll be pre-populated with the last "p1"
                type(into: ptn.window, entry("pA", "tB", "nC"))
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Dismiss morning goals prompt") {
                // we don't care about this, but it happens so we need to account for it
                waitForTransition(of: .morningGoals, toIsVisible: true)
                clickStatusMenu()
            }
            group("Verify entry") {
                let ptn = openPtn()
                let entries = FlatEntry.deserialize(from: ptn.entriesHook.stringValue)
                XCTAssertEqual(
                    [FlatEntry(from: date(h: 6, m: 05), to: date(h: 12, m: 15), project: "pA", task: "tB", notes: "nC")],
                    entries)
            }
        }
        group("Long session while daily report is up") {
            group("Wait until tomorrow") {
                assertThat(window: .ptn, isVisible: true)
                setTimeUtc(d: 1, h: 0, m: 0)
            }
            group("Close PTN and check for no sheet") {
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
                waitForTransition(of: .dailyEnd, toIsVisible: true)
                
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
                waitForTransition(of: .dailyEnd, toIsVisible: false)
            }
            group("Re-open PTN and check for sheet") {
                // Because we clicked out of the last PTN (and thus didn't either continue the session or start a new one),
                // re-opening the PTN should cause us to be instantly re-prompted.
                clickStatusMenu()
                handleLongSessionPrompt(on: .ptn, .startNewSession)
            }
        }
        group("Long session prompt after PTN deferred by daily report") {
            group("Open daily report and fast forward 6 hours") {
                clickStatusMenu(with: .maskAlternate)
                setTimeUtc(d: 1, h: 6, m: 1)
                assertThat(window: .dailyEnd, isVisible: true)
            }
            group("Close daily report and confirm prompt in PTN") {
                clickStatusMenu()
                waitForTransition(of: .dailyEnd, toIsVisible: false)
                wait(for: "PTN to exist", until: {app.windows[WindowType.ptn.windowTitle].exists})
                handleLongSessionPrompt(on: .ptn, .doNothing)
            }
        }
        group("Skip session button") {
            let ptn = findPtn()
            group("Clear out previous entries") {
                handleLongSessionPrompt(on: .ptn, .continueWithCurrentSession)
                ptn.entriesHook.deleteText(andReplaceWith: "\r")
            }
            group("Skip a session") {
                setTimeUtc(d: 1, h: 6, m: 10)
                ptn.window.buttons["Skip session"].click()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Make an entry") {
                setTimeUtc(d: 1, h: 6, m: 15)
                clickStatusMenu() // open the menu
                ptn.pcombo.textField.deleteText(andReplaceWith: "One\tTwo\tThree\r")
            }
            group("Validate") {
                clickStatusMenu()
                let entries = FlatEntry.deserialize(from: ptn.entriesHook.stringValue)
                XCTAssertEqual(
                    [FlatEntry(from: date(d: 1, h: 6, m: 10), to: date(d: 1, h: 6, m: 15), project: "One", task: "Two", notes: "Three")],
                    entries)
            }
        }
        group("Long session while goals prompt is up") {
            group("PTN right before goals") {
                setTimeUtc(d: 1, h: 8, m: 55)
                waitForTransition(of: .ptn, toIsVisible: true)
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Goals prompt") {
                setTimeUtc(d: 1, h: 9, m: 00)
                waitForTransition(of: .morningGoals, toIsVisible: true)
            }
            group("Long session") {
                setTimeUtc(d: 1, h: 15, m: 00)
                handleLongSessionPrompt(on: .morningGoals, .startNewSession)
            }
        }
    }
    
    func testResizing() {
        let ptn = openPtn()
        func checkVerticalAlignments() {
            group("Check vertical alignments") {
                let pY = ptn.pcombo.textField.frame.minY
                let yY = ptn.tcombo.textField.frame.minY
                let nY = ptn.nfield.frame.minY
                XCTAssertEqual(pY, yY)
                XCTAssertEqual(yY, nY)
                XCTAssertEqual(pY, ptn.window.staticTexts["/"].frame.minY)
                XCTAssertEqual(pY, ptn.window.staticTexts[":"].frame.minY)
            }
        }
        func typeUntilWrapping(field: XCUIElement, lines: Int) -> CGFloat {
            let words = String(repeating: "the quick brown fox jumped over the lazy dog ", count: 5).split(separator: " ")
            field.click()
            var wrapsRemaining = lines - 1 // for instance, if we need two lines, we need to wrap once
            var oldHeight = field.frame.height
            for word in words {
                field.typeText("\(word) ")
                let newHeight = field.frame.height
                XCTAssertGreaterThanOrEqual(newHeight, oldHeight)
                if newHeight > oldHeight {
                    wrapsRemaining -= 1
                    if wrapsRemaining == 0 {
                        return newHeight
                    } else {
                        oldHeight = newHeight
                    }
                }
            }
            XCTFail("ran out of words before reaching expected wrap")
            return -1 // won't ever happen
        }
        
        let (originalHeightT, originalHeightN) = group("Get baseline") {() -> (CGFloat, CGFloat) in
            checkVerticalAlignments()
            return (ptn.tcombo.textField.frame.height, ptn.nfield.frame.height)
        }
        
        ///  For each of {P, T, N}:
        /// 1. Type some text until it wraps (to a different number of lines for each one)
        /// 2. Check that everything is still aligned to top
        /// 3. Check that the other two fields haven't changed heights
        let newHeightP = group("type wrapping text into project") {() -> CGFloat in
            let pHeight = typeUntilWrapping(field: ptn.pcombo.textField, lines: 4)
            checkVerticalAlignments()
            XCTAssertEqual(originalHeightT, ptn.tcombo.textField.frame.height)
            XCTAssertEqual(originalHeightN, ptn.nfield.frame.height)
            return pHeight
        }
        let newHeightT = group("type wrapping text into task") {() -> CGFloat in
            let tHeight = typeUntilWrapping(field: ptn.tcombo.textField, lines: 3)
            checkVerticalAlignments()
            XCTAssertEqual(newHeightP, ptn.pcombo.textField.frame.height)
            XCTAssertEqual(originalHeightN, ptn.nfield.frame.height)
            return tHeight
        }
        group("type wrapping text into notes") {
            let _ = typeUntilWrapping(field: ptn.nfield, lines: 2)
            checkVerticalAlignments()
            XCTAssertEqual(newHeightP, ptn.pcombo.textField.frame.height)
            XCTAssertEqual(newHeightT, ptn.tcombo.textField.frame.height)
        }
    }
    
    func testResizingAndAutoComplete() {
        let ptn = openPtn()
        group("initalize the data") {
            // Three entries, in shuffled alphabetical order (neither fully ascending or descending)
            // We want both the lowest and highest values (alphanumerically) to be in the middle.
            // That means that when we autocomplete "wh*", we can be sure that we're getting date-ordered
            // entries.
            let entriesSerialized = FlatEntry.serialize(
                entry("wheredid", "something else", "notes 2", from: t(-100), to: t(-90)),
                entry("whatdid", "autothing", "notes 1", from: t(-80), to: t(-70)),
                entry("whytdid", "autothing", "notes 1", from: t(-80), to: t(-70)),
                entry("whodid", "something else", "notes 2", from: t(-60), to: t(-50)))
            ptn.entriesHook.deleteText(andReplaceWith: entriesSerialized + "\r")
        }
        group("autocomplete wh*") {
            let pcombo = ptn.pcombo.textField
            pcombo.click()
            pcombo.typeKey(.downArrow)
            pcombo.typeText("\r")
            XCTAssertEqual("whodid", pcombo.stringValue)
        }
    }
    func testFocus() {
        let ptn = openPtn()
        group("Set up hot key") {
            let prefsButton = ptn.window.buttons["Preferences"]
            let prefsSheet = ptn.window.sheets.firstMatch
            prefsButton.click()
            XCTAssertTrue(prefsSheet.isVisible)
            prefsSheet.tabs["General"].click()
            prefsSheet.searchFields["Record Shortcut"].click()
            ptn.window.typeKey("x", modifierFlags:[.command, .shift])
            prefsSheet.buttons["Done"].click()
        }
        group("Scheduled PTN does not activate") {
            setTimeUtc(h: 01, m: 00, deactivate: true)
            sleep(1) // If it was going to be switch to active, this would be enough time
            XCTAssertTrue(ptn.window.isVisible)
            XCTAssertEqual(XCUIApplication.State.runningBackground, app.state)
        }
        group("Hot key grabs focus with PTN open") {
            // Assume from previous that window is visible but app is in background
            pressHotkeyShortcut()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
            group("Type text to sanity check focus") {
                ptn.pcombo.textField.typeText("hello 1")
                XCTAssertEqual("hello 1", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.deleteText()
            }
        }
        group("Closing the menu resigns active") {
            clickStatusMenu() // close the app
            wait(for: "window to close", until: {openWindow == nil})
            XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15))
        }
        group("Hot key opens PTN with active and focus") {
            pressHotkeyShortcut()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
            group("Type text to check focus") {
                ptn.pcombo.textField.typeText("hello 2")
                XCTAssertEqual("hello 2", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.deleteText()
            }
        }
        group("Opening the menu activates") {
            group("Close PTN") {
                clickStatusMenu() // close the app
                waitForTransition(of: .ptn, toIsVisible: false)
                XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15))
            }
            clickStatusMenu() // But do *not* do anything more than that to grab focus!
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
            group("Type text to check focus") {
                ptn.pcombo.textField.typeText("hello 3")
                XCTAssertEqual("hello 3", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.deleteText()
            }
        }
        group("Clicking selects all") {
            group("Setup") {
                ptn.pcombo.textField.click()
                ptn.window.typeText("Project 1\tTask 1\tNotes 1")
            }
            group("Click in Task field") {
                XCTAssertEqual("Task 1", ptn.tcombo.textField.stringValue)
                ptn.tcombo.textField.click()
                ptn.window.typeText("Task Two")
                XCTAssertEqual("Task Two", ptn.tcombo.textField.stringValue)
            }
            group("Click in Project field") {
                XCTAssertEqual("Project 1", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.click()
                ptn.window.typeText("Project Two")
                XCTAssertEqual("Project Two", ptn.pcombo.textField.stringValue)
            }
            group("Click in Notes field") {
                XCTAssertEqual("Notes 1", ptn.nfield.stringValue)
                ptn.nfield.click()
                ptn.window.typeText("Notes Two")
                XCTAssertEqual("Notes Two", ptn.nfield.stringValue)
            }
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
                    dismiss(window: .dailyEnd)
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
                        dismiss(window: .dailyEnd)
                        dismiss(window: .morningGoals)
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
    
    func testKeyboardNavigation() {
        let ptn = openPtn()
        group("forward tabbing") {
            XCTAssertTrue(ptn.pcombo.hasFocus) // Sanity check
            // Tab from Project -> Task
            ptn.window.typeKey(.tab)
            XCTAssertTrue(ptn.tcombo.hasFocus)
            // Tab from Task -> Notes
            ptn.window.typeKey(.tab)
            XCTAssertTrue(ptn.window.textFields["nfield"].hasFocus)
        }
        group("backward tabbing") {
            XCTAssertTrue(ptn.window.textFields["nfield"].hasFocus) // Sanity check
            // Backtab from Notes to Task
            ptn.window.typeKey(.tab, modifierFlags: .shift)
            XCTAssertTrue(ptn.tcombo.hasFocus)
            // Backtab from Task to Project
            ptn.window.typeKey(.tab, modifierFlags: .shift)
            XCTAssertTrue(ptn.pcombo.hasFocus)
        }
        group("enter key") {
            XCTAssertTrue(ptn.pcombo.hasFocus) // Sanity check
            // Enter from Project to Task
            ptn.pcombo.textField.typeKey(.enter)
            XCTAssertTrue(ptn.tcombo.hasFocus)
            // Enter from Task to Notes
            ptn.pcombo.textField.typeKey(.enter)
            XCTAssertTrue(ptn.window.textFields["nfield"].hasFocus)
        }
        group("escape key within notes") {
            XCTAssertTrue(ptn.window.textFields["nfield"].hasFocus)
            ptn.window.typeKey(.escape, modifierFlags: [])
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("escape key within project combo") {
            group("Open PTN") {
                wait(for: "window to close", until: {openWindow == nil})
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: true)
            }
            group("Escape key #1: hide options") {
                XCTAssertTrue(ptn.pcombo.textField.hasFocus)
                XCTAssertTrue(ptn.pcombo.optionsScroll.isVisible)
                ptn.window.typeKey(.escape, modifierFlags: [])
                XCTAssertFalse(ptn.pcombo.optionsScrollIsOpen)
            }
            group("Escape key #2: hide window") {
                waitForTransition(of: .ptn, toIsVisible: true)
                ptn.window.typeKey(.escape, modifierFlags: [])
                waitForTransition(of: .ptn, toIsVisible: false)
            }
        }
    }
    
    func testDailyReportResizing() {
        let longProjectName = "The quick brown fox jumped over the lazy dog because the dog was just so lazy. Poor dog."
        group("Set up events with long text") {
            let twelveHoursFromEpoch = Date(timeIntervalSince1970: 43200)
            let entries = FlatEntry.serialize(
                entry(
                    longProjectName,
                    "Some task",
                    "Some notes",
                    from: twelveHoursFromEpoch,
                    to: twelveHoursFromEpoch.addingTimeInterval(60)),
                entry(
                    "short project",
                    "short task",
                    "short notes",
                    from: twelveHoursFromEpoch.addingTimeInterval(60),
                    to: twelveHoursFromEpoch.addingTimeInterval(120)),
                entry(
                    "short project",
                    "short task",
                    String(repeating: "here are some long notes ", count: 3),
                    from: twelveHoursFromEpoch.addingTimeInterval(120),
                    to: twelveHoursFromEpoch.addingTimeInterval(180))
                )
            let ptn = openPtn()
            ptn.entriesHook.click()
            ptn.window.typeText(entries + "\r")
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        let originalWindowFrame = group("Open report in two days") {() -> CGRect in
            dragStatusMenu(to: NSScreen.main!.frame.maxX)
            setTimeUtc(d: 2)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            // When we start the new session, the PTN will disappear, but the daily report will open (since we're past the scheduled date).
            // Sanity check that the frame's right edge is at the screen's right edge.
            let dailyReportFrame = self.app.windows[WindowType.dailyEnd.windowTitle].firstMatch.frame
            XCTAssertEqual(NSScreen.main!.frame.width, dailyReportFrame.maxX)
            return dailyReportFrame
        }
        group("Set time back") {
            // Our current date is 1/2/1970 00:00:00, and the report starts at the 7am before that. We want the previous day's,
            // which goes from 12/31/1969 07:00:00 to 1/1/1970 00:00:00.
            let dailyReportWindow = app.windows[WindowType.dailyEnd.windowTitle].firstMatch
            XCTAssertTrue(dailyReportWindow.datePickers.firstMatch.hasFocus) // sanity check
            dailyReportWindow.typeKey(.tab) // tab to the date portion, then arrowdown to decrement it
            dailyReportWindow.typeKey(.downArrow)
        }
        group("Confirm that the report has the entry") {
            let dailyReportWindow = app.windows[WindowType.dailyEnd.windowTitle].firstMatch
            let project = HierarchicalEntryLevel(ancestor: dailyReportWindow, scope: "Project", label: longProjectName)
            let firstVisibleElement = project.allElements.values.first(where: {$0.isVisible})
            if let visible = firstVisibleElement {
                log("found: \(visible.simpleDescription)")
            }
            XCTAssertNotNil(firstVisibleElement, "Project not visible")
        }
        group("Check that the window is still within the original bounds") {
            let dailyReportWindow = app.windows[WindowType.dailyEnd.windowTitle].firstMatch
            let dailyReportFrame = dailyReportWindow.frame
            XCTAssertEqual(dailyReportFrame.minX, originalWindowFrame.minX)
            XCTAssertEqual(dailyReportFrame.maxX, originalWindowFrame.maxX)
            let project = HierarchicalEntryLevel(ancestor: dailyReportWindow, scope: "Project", label: longProjectName)
            for (description, e) in project.allElements {
                XCTAssertTrue(e.isVisible, description)
            }
        }
        group("Check the long notes") {
            let (shortTaskElem, longTaskElem) = group("Open project and task") {() -> (XCUIElement, XCUIElement) in
                let dailyReportWindow = app.windows[WindowType.dailyEnd.windowTitle].firstMatch
                let shortProject = HierarchicalEntryLevel(ancestor: dailyReportWindow, scope: "Project", label: "short project")
                shortProject.disclosure.click()
                wait(for: "project to open", until: {dailyReportWindow.groups.count > 0})
                
                let tasksForProject = dailyReportWindow.groups["Tasks for \"short project\""]
                let task = HierarchicalEntryLevel(ancestor: tasksForProject, scope: "Task", label: "short task")
                task.disclosure.click()
                wait(for: "task details to open", until: {tasksForProject.groups.staticTexts.count == 4})
                
                let taskDetails = tasksForProject.groups["Details for short task"]
                // the details texts are: [0] time header for short task, [1] short task text, [2] time header for long task, [3] long task text
                let detailTexts = taskDetails.staticTexts.allElementsBoundByIndex
                return (detailTexts[1], detailTexts[3])
            }
            group("Validate task elements") {
                XCTAssertTrue(shortTaskElem.stringValue.contains("short notes"))
                XCTAssertTrue(longTaskElem.stringValue.contains("here are some long notes"))
                // Make sure the long task height is at least 1.9x the short task height. I would expect it to be 2x, but I'm allowing for
                // rounding layout squashing, etc.
                XCTAssertGreaterThanOrEqual(longTaskElem.frame.height, shortTaskElem.frame.height * 1.9)
            }
            
        }
        group("Close the daily report") {
            clickStatusMenu()
        }
    }
    
    func testFieldClearingOnPopup() {
        let ptn = openPtn()
        group("Type project, then abandon") {
            XCTAssertTrue(ptn.pcombo.hasFocus)
            app.typeText("project a\r")
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Type task, then abandon") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertTrue(ptn.tcombo.hasFocus)
            app.typeText("task b\r")
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Enter notes") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertTrue(ptn.nfield.hasFocus)
            app.typeText("notes c\r")
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Reopen PTN") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertTrue(ptn.nfield.hasFocus)
            XCTAssertEqual("", ptn.nfield.stringValue)
        }
        group("Change project") {
            ptn.pcombo.textField.deleteText()
            XCTAssertEqual("", ptn.pcombo.textField.stringValue) // sanity check
            XCTAssertEqual("", ptn.tcombo.textField.stringValue) // changing pcombo should change tcombo
        }
    }
    
    /// Sets the mocked clock in UTC. If `deactivate` is true (default false), then this will set the mocked clock to set the time when the app deactivates, and then this method will activate
    /// the finder. Otherwise, `onSessionPrompt` governs what to do if the "start a new session?" prompt comes up.
    func setTimeUtc(d: Int = 0, h: Int = 0, m: Int = 0, s: Int = 0, deactivate: Bool = false) {
        group("setting time \(d)d \(h)h \(m)m \(s)s") {
            let epochSeconds = d * 86400 + h * 3600 + m * 60 + s
            let text = "\(epochSeconds)\r"
            let mockedClockWindow = app.windows["Mocked Clock"]
            activate()
            app.menuBars.statusItems["Focus Mocked Clock"].click()
            mockedClockWindow.click()
            let clockTicker = mockedClockWindow.children(matching: .textField).element
            if deactivate {
                mockedClockWindow.checkBoxes["Defer until deactivation"].click()
            }
            clockTicker.deleteText(andReplaceWith: text)
            log("Setting time to \(Date(timeIntervalSince1970: TimeInterval(epochSeconds)).utcTimestamp)")
            if deactivate {
                group("Activate Finder") {
                    let finder = NSWorkspace.shared.runningApplications.first(where: {$0.bundleIdentifier == "com.apple.finder"})
                    XCTAssertNotNil(finder)
                    XCTAssertTrue(finder!.activate(options: .activateIgnoringOtherApps))
                    XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15))
                    print("Pausing to let things settle")
                    sleep(1)
                    print("Okay, continuing.")
                }
            }
        }
    }
    
    func handleLongSessionPrompt(on windowType: WindowType, _ action: LongSessionAction) {
        wait(for: "window to exist", until: {openWindow != nil})
        let window = find(windowType)
        XCTAssertNotNil(window.sheets.allElementsBoundByIndex.first(where: {$0.title == "Start new session?"}))
        switch action {
        case .continueWithCurrentSession:
            window.sheets.buttons["Continue with current session"].click()
        case .startNewSession:
            window.sheets.buttons["Start new session"].click()
        case .doNothing:
            break // nothing
        }
    }

    func pressHotkeyShortcut(keyCode: CGKeyCode = 7) {
        // 7 == "x"
        for keyDown in [true, false] {
            let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
            let keyEvent = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: keyDown)
            keyEvent!.flags = [.maskCommand, .maskShift]
            keyEvent?.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }
    
    func find(_ windowType: WindowType) -> XCUIElement {
        guard let (t, e) = openWindowInfo else {
            XCTFail("no window open")
            fatalError("should have failed at XCTFail")
        }
        XCTAssertEqual(windowType, t)
        return e
    }
    
    var openWindowInfo: (WindowType, XCUIElement)? {
        for windowType in WindowType.allCases {
            let maybe = app.windows[windowType.windowTitle]
            if maybe.exists {
                return (windowType, maybe)
            }
        }
        return nil
    }
    
    var openWindow: XCUIElement? {
        openWindowInfo?.1
    }
    
    var openWindowType: WindowType? {
        openWindowInfo?.0
    }
    
    func type(into app: XCUIElement, _ entry: FlatEntry) {
        app.comboBoxes["pcombo"].children(matching: .textField).firstMatch.click()
        for text in [entry.project, entry.task, entry.notes ?? ""] {
            app.typeText(text + "\r")
        }
    }
    
    func date(d: Int = 0, h: Int, m: Int) -> Date {
        let epochSeconds = d * 86400 + h * 3600 + m * 60
        return Date(timeIntervalSince1970: TimeInterval(epochSeconds))
    }
    
    func entry(_ project: String, _ task: String, _ notes: String?) -> FlatEntry {
        return entry(project, task, notes, from: t(0), to: t(0))
    }
    
    func entry(_ project: String, _ task: String, _ notes: String?, from: Date, to: Date) -> FlatEntry {
        return FlatEntry(from: from, to: to, project: project, task: task, notes: notes)
    }
    
    class func t(_ timeDelta: TimeInterval) -> Date {
        return PtnViewControllerTest.SOME_TIME.addingTimeInterval(timeDelta)
    }
    
    func t(_ timeDelta: TimeInterval) -> Date {
        return PtnViewControllerTest.t(timeDelta)
    }
    
    // assertThat(window: .ptn, isVisible: true)
    func assertThat(window: WindowType, isVisible expected: Bool) {
        XCTAssertEqual(expected, isWindowVisible(window))
    }
    
    func waitForTransition(of window: WindowType, toIsVisible expected: Bool) {
        wait(
            for: "\(String(describing: window)) to \(expected ? "exist" : "not exist")",
            until: {self.isWindowVisible(window) == expected })
    }
    
    func dismiss(window: WindowType) {
        waitForTransition(of: window, toIsVisible: true)
        clickStatusMenu()
        waitForTransition(of: window, toIsVisible: false)
    }
    
    func isWindowVisible(_ window: WindowType) -> Bool {
        return app.windows.matching(NSPredicate(format: "title = %@", window.windowTitle)).count > 0
    }
    
    struct HierarchicalEntryLevel {
        let ancestor: XCUIElement
        let scope: String
        let label: String
        
        var headerLabel: XCUIElement {
            ancestor.staticTexts["\(scope) \"\(label)\""].firstMatch
        }
        
        var durationLabel: XCUIElement {
            ancestor.staticTexts["\(scope) time for \"\(label)\""].firstMatch
        }
        
        var disclosure: XCUIElement {
            ancestor.disclosureTriangles["\(scope) details toggle for \"\(label)\""]
        }
        
        var indicatorBar: XCUIElement {
            ancestor.progressIndicators["\(scope) activity indicator for \"\(label)\""]
        }
        
        var allElements: [String: XCUIElement] {
            return ["headerText": headerLabel, "durationText": durationLabel, "disclosure": disclosure, "indicator": indicatorBar]
        }
        
        func clickDisclosure(until element: XCUIElement, _ existence: Existence) {
            XCTContext.runActivity(named: "Click \(disclosure.simpleDescription)") {context in
                context.add(XCTAttachment(screenshot: ancestor.screenshot()))
                disclosure.click()
                wait(for: "element to \(existence.asVerb)") {
                    switch existence {
                    case .exists:
                        return element.exists
                    case .isVisible:
                        return element.isVisible
                    case .doesNotExist:
                        return !element.exists
                    }
                }
                context.add(XCTAttachment(screenshot: ancestor.screenshot()))
            }
        }
    }
    
    enum Existence {
        case exists
        case isVisible
        case doesNotExist
        
        var asVerb: String {
            switch self {
            case .exists:
                return "exist"
            case .isVisible:
                return "be visible"
            case .doesNotExist:
                return "not exist"
            }
        }
    }
    
    enum LongSessionAction {
        case continueWithCurrentSession
        case startNewSession
        case doNothing
    }
    
    struct Ptn {
        let window: XCUIElement
        let pcombo: AutocompleteFieldHelper
        let tcombo: AutocompleteFieldHelper
        
        var nfield: XCUIElement {
            window.textFields["nfield"]
        }
        
        var entriesHook: XCUIElement {
            window.textFields["uihook_flatentryjson"]
        }
    }
    
    enum WindowType: CaseIterable {
        case ptn
        case dailyEnd
        case morningGoals
        
        var windowTitle: String {
            switch self {
            case .ptn:
                return "What are you working on?"
            case .dailyEnd:
                return "Here's what you've been doing"
            case .morningGoals:
                return "Start the day with some goals"
            }
        }
    }
}
