// whatdidUITests?

import XCTest
@testable import whatdid

class PtnViewControllerTest: XCTestCase {
    private static let SOME_TIME = Date()
    private var app : XCUIApplication!
    /// A point within the status menu item. See `clickStatusMenu()`
    private var statusItemPoint: CGPoint!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        findStatusMenuItem()
        let now = Date()
        log("Failed at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
    }
    
    func activate(andClickActivatorStatusItem: Bool) {
        app.activate()
        if andClickActivatorStatusItem {
            app.menuBars.statusItems["Activate Whatdid"].click()
        }
    }
    
    func findStatusMenuItem() {
        activate(andClickActivatorStatusItem: false)
        // The 0.5 isn't necessary, but it positions the cursor in the middle of the item. Just looks nicer.
        app.menuBars.statusItems["✐"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        statusItemPoint = CGEvent(source: nil)?.location
    }
    
    override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
        let now = Date()
        log("Failed at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
        super.recordFailure(withDescription: description, inFile: filePath, atLine: lineNumber, expected: expected)
    }
    
    func openPtn(andThen afterAction: (XCUIElement) -> () = {_ in }) -> Ptn {
        return group("open PTN") {
            switch openWindow {
            case .none:
                clickStatusMenu()
            case let .some(w) where w.title == WindowType.dailyEnd.windowTitle:
                clickStatusMenu()
                sleepMillis(500)
                clickStatusMenu()
            case let .some(w) where w.title == WindowType.ptn.windowTitle:
                break
            case let .some(w):
                XCTFail("unexpected window: \(w.title)")
            }
            let ptn = findPtn()
            if !ptn.window.isVisible {
                clickStatusMenu()
            }
            assertThat(window: .ptn, isVisible: true)
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
    
    func clickStatusMenu(with flags: CGEventFlags = []){
        // In headless mode (or whatever GH actions uses), I can't just use the XCUIElement's `click()`
        // when the app is in the background. Instead, I fetched the status item's location during setUp, and
        // now directly post the click events to it.
        group("Click status menu") {
            for eventType in [CGEventType.leftMouseDown, CGEventType.leftMouseUp] {
                clickEvent(.left, eventType, at: statusItemPoint, with: flags)
            }
        }
    }
    
    func dragStatusMenu(to newX: CGFloat) {
        group("Drag status menu") {
            clickEvent(.left, .leftMouseDown, at: statusItemPoint, with: .maskCommand)
            clickEvent(.left, .leftMouseUp, at: CGPoint(x: newX, y: statusItemPoint.y), with: [])
            let oldPoint = statusItemPoint!
            findStatusMenuItem()
            
            addTeardownBlock {
                self.group("Drag status menu back") {
                    self.clickEvent(.left, .leftMouseDown, at: self.statusItemPoint, with: .maskCommand)
                    self.clickEvent(.left, .leftMouseUp, at: oldPoint, with: [])
                    self.findStatusMenuItem()
                }
            }
        }
    }
    
    func clickEvent(_ mouseButton: CGMouseButton, _ mouseType: CGEventType, at position: CGPoint, with flags: CGEventFlags) {
        let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
        let downEvent = CGEvent(mouseEventSource: src, mouseType: mouseType, mouseCursorPosition: position, mouseButton: mouseButton)
        downEvent?.flags = flags
        downEvent?.post(tap: CGEventTapLocation.cghidEventTap)
        pauseToLetStabilize()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }
    
    func testScheduling() {
        let ptn = app.windows[WindowType.ptn.windowTitle]
        
        // Note: Time starts at 02:00:00 local
        group("basic PTN scheduling") {
            // Default is 12 minutes +/- 2.
            setTimeUtc(h: 0, m: 9) // 02:09; too soon for the popup
            pauseToLetStabilize()
            assertThat(window: .ptn, isVisible: false)
            setTimeUtc(h: 0, m: 15) // 02:15; enough time for the popup
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertTrue(findPtn().pcombo.hasFocus)
            ptn.typeText("Project\tTask\tNotes\r")
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Writing an entry resets the timer") {
            group("Wait 9 minutes") {
                setTimeUtc(h: 0, m: 24) // 15 + 9 -- so not enough time to set a popup
                pauseToLetStabilize()
                assertThat(window: .ptn, isVisible: false)
            }
            group("Manually open PTN and add entry") {
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: true)
                ptn.typeText("Notes 2\r") // Project and Task are already filled out
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Wait another 9 minutes") {
                // If the previous group didn't reset the timer, we'd have gotten a scheduled PTN by now,
                // since it'd be 18 minutes since the last PTN (so more than the 12 + 2 max schedule time).
                // We expect that the previous group *did* reset the schedule, though, so we won't get one.
                setTimeUtc(h: 0, m: 33)
                pauseToLetStabilize()
                assertThat(window: .ptn, isVisible: false)
            }
            group("Open and close PTN without adding entry") {
                group("Open and close PTN") {
                    clickStatusMenu()
                    waitForTransition(of: .ptn, toIsVisible: true)
                    clickStatusMenu()
                    waitForTransition(of: .ptn, toIsVisible: false)
                }
                group("Wait a final 9 minutes") {
                    // Opening and closing the PTN (without saving an entry) does *not* reset the clock,
                    // so by now we've waited 42 - 24 = 18 minutes since the last reset (which was when we
                    // manually opened the PTN to add an entry). We expect a popup.
                    setTimeUtc(h: 0, m: 42)
                    waitForTransition(of: .ptn, toIsVisible: true)
                }
            }
        }
        group("Check snooze option updates") {
            let button = ptn.buttons["snoozebutton"]
            group("Initial state") {
                // It's now 1970-01-02 16:31:00 UTC, which is 6:31 pm. Check that the default snooze option is to 7:00.
                XCTAssertEqual("Snooze until 3:00 am", button.title.trimmingCharacters(in: .whitespaces))
                XCTAssertTrue(button.isEnabled)
            }
            group("Wait until right before the update") {
                setTimeUtc(h:0, m: 54, s: 59)
                // Unchanged
                XCTAssertEqual("Snooze until 3:00 am", button.title.trimmingCharacters(in: .whitespaces))
                XCTAssertTrue(button.isEnabled)
                XCTAssertEqual(0, ptn.activityIndicators.count) // spinner
            }
            group("Update is in progress") {
                setTimeUtc(h: 0, m: 55, s: 00)
                // Text is unchanged, but button is disabled
                XCTAssertEqual("Snooze until 3:00 am", button.title.trimmingCharacters(in: .whitespaces))
                XCTAssertFalse(button.isEnabled)
                wait(for: "spinner", timeout: 5, until: {ptn.activityIndicators.count == 1})
            }
            group("Update is done") {
                setTimeUtc(h: 0, m: 55, s: 01)
                // Update complete
                XCTAssertEqual("Snooze until 3:30 am", button.title.trimmingCharacters(in: .whitespaces))
                XCTAssertTrue(button.isEnabled)
                wait(for: "spinner", timeout: 5, until: {ptn.activityIndicators.count == 0})
            }
        }
        group("Check snooze-until-tomorrow option") {
            // It's currently 6:55 pm on Friday, Jan 2. So "tomorrow" is actually Monday.
            // The default option is 7:30 pm, and the extra options start at 8:00 pm.
            ptn.menuButtons["snoozeopts"].click()
            let snoozeOptions = ptn.menuButtons["snoozeopts"].descendants(matching: .menuItem)
            let snoozeOptionLabels = snoozeOptions.allElementsBoundByIndex.map { $0.title }
            XCTAssertEqual(["4:00 am", "4:30 am", "5:00 am", "", "9:00 am"], snoozeOptionLabels)
        }
        group("Header text") {
            XCTAssertEqual(
                "What have you been working on for the last 31m (since 2:24 am)?",
                ptn.staticTexts["durationheader"].stringValue)
            setTimeUtc(h: 0, m: 56)
            XCTAssertEqual(
                "What have you been working on for the last 32m (since 2:24 am)?",
                ptn.staticTexts["durationheader"].stringValue)
        }
        group("snooze button: standard press") {
            // Note: PTN is still up at this point.
            let button = ptn.buttons["snoozebutton"]
            // It's 02:55 now, so we add 15 minutes and then round to the next highest half-hour. That means
            // the default snooze is 3:30.
            // Trim whitespace, since we put some in so it aligns well with the snoozeopts button
            XCTAssertEqual("Snooze until 3:30 am", button.title.trimmingCharacters(in: .whitespaces))
            button.click()
            waitForTransition(of: .ptn, toIsVisible: false)
            
            // To go 03:29+0200, and the PTN should still be hidden
            setTimeUtc(h: 1, m: 29)
            assertThat(window: .ptn, isVisible: false)

            // But one more minute, and it is visible again
            setTimeUtc(h: 1, m: 31)
            waitForTransition(of: .ptn, toIsVisible: true)
        }
        group("snooze button: extra options") {
            // Note: PTN is still up at this point. It's currently 03:31+0200, so the default snooze is at 04:00,
            // and the options start at 04:30
            ptn.menuButtons["snoozeopts"].click()
            let snoozeOptions = ptn.menuButtons["snoozeopts"].descendants(matching: .menuItem)
            let snoozeOptionLabels = snoozeOptions.allElementsBoundByIndex.map { $0.title }
            XCTAssertEqual(["4:30 am", "5:00 am", "5:30 am", "", "9:00 am"], snoozeOptionLabels)
            ptn.menuItems["5:30 am"].click()
            
            // To go 03:29+0200, and the PTN should still be hidden
            
            setTimeUtc(h: 3, m: 29)
            waitForTransition(of: .ptn, toIsVisible: false)

            // But one more minute, and it is visible again
            setTimeUtc(h: 3, m: 31)
            waitForTransition(of: .ptn, toIsVisible: true)
        }
        group("unsnooze before first scheduled PTN") {
            // Note: PTN is still up at this point.
            let button = ptn.buttons["snoozebutton"]
            group("Start snoozing") {
                XCTAssertEqual("Snooze until 6:00 am", button.title.trimmingCharacters(in: .whitespaces))
                button.click()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Unsnooze a minute later") {
                setTimeUtc(h: 3, m: 32)
                assertThat(window: .ptn, isVisible: false) // sanity check that we're still closed
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: true)
                
                button.click() // open up the unsnooze
                button.buttons["Unsnooze"].click()
                assertThat(window: .ptn, isVisible: true) // unsnoozing doesn't close the window
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Fast-forward to after the PTN will pop up") {
                setTimeUtc(h: 3, m: 51)
                waitForTransition(of: .ptn, toIsVisible: true)
            }
        }
        group("unsnooze after scheduled PTN; close without adding entry") {
            // Note: PTN is still up at this point.
            let button = ptn.buttons["snoozebutton"]
            group("Start snoozing until 6:30") {
                XCTAssertEqual("Snooze until 6:30 am", button.title.trimmingCharacters(in: .whitespaces))
                button.click()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Unsnooze at 6:29") {
                setTimeUtc(h: 4, m: 29)
                assertThat(window: .ptn, isVisible: false) // still snoozing
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: true)
                
                button.click() // open up the unsnooze
                button.buttons["Unsnooze"].click()
            }
            group("Close PTN without adding entry") {
                assertThat(window: .ptn, isVisible: true)
                clickStatusMenu() // close the window
                sleep(1)
                assertThat(window: .ptn, isVisible: false)
            }
            group("Wait another 25 minutes") {
                setTimeUtc(h: 4, m: 55)
                waitForTransition(of: .ptn, toIsVisible: true)
            }
        }
        group("unsnooze after scheduled PTN; close by adding an entry") {
            // Note: PTN is still up at this point.
            let button = ptn.buttons["snoozebutton"]
            group("Start snoozing until 7:30") {
                XCTAssertEqual("Snooze until 7:30 am", button.title.trimmingCharacters(in: .whitespaces))
                button.click()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Unsnooze at 7:29") {
                setTimeUtc(h: 5, m: 29)
                assertThat(window: .ptn, isVisible: false) // still snoozing
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: true)
                
                button.click() // open up the unsnooze
                button.buttons["Unsnooze"].click()
            }
            group("Add an entry") {
                let ptnStruct = findPtn()
                XCTAssertTrue(ptnStruct.nfield.hasFocus) // Remember from above, project and task are already filled
                ptnStruct.nfield.typeText("Notes 3\r")
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Wait another 25 minutes") {
                setTimeUtc(h: 5, m: 55)
                waitForTransition(of: .ptn, toIsVisible: true)
            }
            group("Cleanup") {
                let ptnStruct = findPtn()
                ptnStruct.pcombo.textField.deleteText()
                ptnStruct.entriesHook.deleteText(andReplaceWith: "\r")
                for textField in [ptnStruct.pcombo.textField, ptnStruct.tcombo.textField, ptnStruct.nfield] {
                    XCTAssertEqual("", textField.stringValue)
                }
            }
        }
        group("daily report (no contention with PTN)") {
            // Note: PTN is still up at this point. It's currently 05:31+0200.
            // We'll bring it to 18:29, and then dismiss it.
            // Then the next minute, there should be the daily report
            setTimeUtc(h: 16, m: 29, onSessionPrompt: .continueWithCurrentSession)
            type(into: app, entry("my project", "my task", "my notes"))
            waitForTransition(of: .ptn, toIsVisible: false)
            
            setTimeUtc(h: 16, m: 30)
            assertThat(window: .ptn, isVisible: false)
            activate(andClickActivatorStatusItem: true)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
            clickStatusMenu() // close the report
            waitForTransition(of: .dailyEnd, toIsVisible: false)
        }
        group("daily report (with contention with PTN)") {
            // Fast-forward a day. At 18:29 local, we should get a PTN.
            // Wait two minutes (so that the daily report is due) and then type in an entry.
            // We should get the daily report next, which we should then be able to dismiss.
            group("A day later, just before the daily report") {
                setTimeUtc(d: 1, h: 16, m: 29, onSessionPrompt: .continueWithCurrentSession)
                waitForTransition(of: .ptn, toIsVisible: true)
            }
            group("Now at the daily report") {
                setTimeUtc(d: 1, h: 16, m: 31)
                assertThat(window: .dailyEnd, isVisible: false)
                assertThat(window: .ptn, isVisible: true)
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
                // Also wait a second, so that we can be sure it didn't pop back open (GH #72)
                Thread.sleep(forTimeInterval: 1)
                assertThat(window: .dailyEnd, isVisible: false)
                assertThat(window: .ptn, isVisible: false)
            }
        }
        group("Check snooze-until-tomorrow option") {
            // We had a similar check above, but let's redo it so we capture weekend state.
            // It's currently 6:31 pm on Friday, Jan 2. So "tomorrow" is actually Monday.
            // The default option is 7:30 pm, and the extra options start at 8:00 pm.
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            ptn.menuButtons["snoozeopts"].click()
            let snoozeOptions = ptn.menuButtons["snoozeopts"].descendants(matching: .menuItem)
            let snoozeOptionLabels = snoozeOptions.allElementsBoundByIndex.map { $0.title }
            XCTAssertEqual(["7:30 pm", "8:00 pm", "8:30 pm", "", "Monday at 9:00 am"], snoozeOptionLabels)
        }
    }
    
    func testLongSessionPrompt() {
        group("Long session while PTN is open") {
            clickStatusMenu()
            setTimeUtc(d: 0, h: 5, m: 59, onSessionPrompt: .ignorePrompt)
            checkLongSessionPrompt(exists: false)
            setTimeUtc(d: 0, h: 6, m: 00, onSessionPrompt: .ignorePrompt)
            checkLongSessionPrompt(exists: true)
        }
        group("New session resets the time") {
            group("Select option to start new session") {
                handleLongSessionPrompt(.startNewSession)
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
        group("Long session while PTN is closed") {
            group("Close PTN") {
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
                waitForTransition(of: .dailyEnd, toIsVisible: false)
            }
            group("Go forward 6 more hours") {
                setTimeUtc(d: 0, h: 12, m: 10, onSessionPrompt: .ignorePrompt)
                checkLongSessionPrompt(exists: true)
            }
        }
        group("Continuing session keeps the time") {
            group("Select option to continue session") {
                handleLongSessionPrompt(.continueWithCurrentSession)
            }
            group("Create an entry") {
                setTimeUtc(d: 0, h: 12, m: 15)
                let ptn = findPtn()
                ptn.pcombo.textField.deleteText() // since it'll be pre-populated with the last "p1"
                type(into: ptn.window, entry("pA", "tB", "nC"))
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("Verify entry") {
                let ptn = openPtn()
                let entries = FlatEntry.deserialize(from: ptn.entriesHook.stringValue)
                XCTAssertEqual(
                    [FlatEntry(from: date(h: 6, m: 05), to: date(h: 12, m: 15), project: "pA", task: "tB", notes: "nC")],
                    entries)
            }
        }
        group("Long session with contention with daily report") {
            group("Wait until tomorrow") {
                assertThat(window: .ptn, isVisible: true)
                setTimeUtc(d: 1, h: 0, m: 0, onSessionPrompt: .ignorePrompt)
            }
            group("Close PTN and check for no sheet") {
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
                checkLongSessionPrompt(exists: false)
                waitForTransition(of: .dailyEnd, toIsVisible: true)
                
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
                waitForTransition(of: .dailyEnd, toIsVisible: false)
            }
            group("Re-open PTN and check for sheet") {
                // Because we clicked out of the last PTN (and thus didn't either continue the session or start a new one),
                // re-opening the PTN should cause us to be instantly re-prompted.
                clickStatusMenu()
                checkLongSessionPrompt(exists: true)
                handleLongSessionPrompt(.startNewSession)
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
                checkLongSessionPrompt(exists: true)
            }
        }
        group("Skip session button") {
            let ptn = findPtn()
            group("Clear out previous entries") {
                handleLongSessionPrompt(.continueWithCurrentSession)
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
    
    func testDailyReportPopup() {
        let entries = EntriesBuilder()
            .add(project: "project a", task: "task 1", notes: "first thing", minutes: 12)
            .add(project: "project a", task: "task 2", notes: "sidetrack", minutes: 13)
            .add(project: "project a", task: "task 1", notes: "back to first", minutes: 5)
            .add(project: "project b", task: "task 1", notes: "fizz", minutes: 5)
            .add(project: "project c", task: "task 2", notes: "fuzz", minutes: 10)
        group("Initalize the data") {
            let ptn = openPtn()
            let entriesTextField  = ptn.entriesHook
            entriesTextField.deleteText(andReplaceWith: FlatEntry.serialize(entries.get()))
            entriesTextField.typeKey(.enter)
            clickStatusMenu()
        }
        let dailyReport = app.windows[WindowType.dailyEnd.windowTitle]
        group("Open daily report") {
            clickStatusMenu(with: .maskAlternate)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
        }
        func verifyProjectsVisibility() {
            group("Verify projects are visible") {
                for project in ["project a", "project b", "project c"] {
                    group(project) {
                        for (description, e) in HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: project).allElements {
                            XCTAssertTrue(e.isVisible, "\"\(project)\" \(description) are visible")
                        }
                    }
                }
            }
        }
        verifyProjectsVisibility()
        group("Verify projects visible after contention with PTN") {
            group("Close the report and set up contention") {
                clickStatusMenu() // close daily report
                let ptn = openPtn()
                ptn.entriesHook.deleteText(andReplaceWith: FlatEntry.serialize(entries.get(startingAtSecondsSince1970: 86400)) + "\r")
                setTimeUtc(d: 1, h: 0, m: 0, onSessionPrompt: .startNewSession) // also closes the PTN
                waitForTransition(of: .ptn, toIsVisible: false)
                waitForTransition(of: .dailyEnd, toIsVisible: true)
            }
            verifyProjectsVisibility()
        }
        group("Spot check on project a") {
            let projectA = HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: "project a")
            let tasksForA = dailyReport.groups["Tasks for \"project a\""]
            let task1 = HierarchicalEntryLevel(ancestor: tasksForA, scope: "Task", label: "task 1")
            let task1Details = tasksForA.staticTexts["Details for task 1"]
            group("Duration label and indicator") {
                XCTAssertEqual("30m", projectA.durationLabel.stringValue)
                if let indicatorBarValue = projectA.indicatorBar.value as? Double {
                    // 30 minutes out of 45 total = 0.6666...
                    XCTAssertGreaterThan(indicatorBarValue, 0.66)
                    XCTAssertLessThan(indicatorBarValue, 0.67)
                }
            }
            group("Check tasks for \"project a\"") {
                XCTAssertFalse(tasksForA.exists)
                projectA.clickDisclosure(until: tasksForA, .isVisible)
            }
            for task in ["task 1", "task 2"] {
                group("Check \(task)'s visibility") {
                    for (description, e) in HierarchicalEntryLevel(ancestor: tasksForA, scope: "Task", label: task).allElements {
                        e.hover()
                        XCTAssertTrue(e.isVisible, "\(task) \(description)")
                    }
                }
            }
            group("Spot check on task 1") {
                group("Duration label and indicator") {
                    XCTAssertEqual("17m", task1.durationLabel.stringValue)
                    if let indicatorBarValue = task1.indicatorBar.value as? Double {
                        // 17 minutes out of 45 total = 0.0.3777...
                        XCTAssertGreaterThan(indicatorBarValue, 0.37)
                        XCTAssertLessThan(indicatorBarValue, 0.38)
                    }
                }
                group("Details") {
                    XCTAssertFalse(task1Details.exists)
                    task1.clickDisclosure(until: task1Details, .isVisible)
                    XCTAssertEqual("1:15am - 1:27am (12m): first thing\n1:40am - 1:45am (5m): back to first", task1Details.stringValue)
                }
            }
            group("Task 1 stays expanded if project a folds") {
                projectA.clickDisclosure(until: task1Details, .doesNotExist)
                log("Sleeping for a bit to let things stabilize")
                sleep(2) // Clicking too quickly in a row can break this test
                projectA.clickDisclosure(until: task1Details, .isVisible)
            }
        }
        group("Projects need to scroll") {
            group("Set new entries") {
                clickStatusMenu() // Close the daily report
                let ptn = openPtn()
                let manyEntries = EntriesBuilder()
                for i in 1...25 {
                    manyEntries.add(project: "project \(i)", task: "only task", notes: "", minutes: Double(i))
                }
                ptn.entriesHook.deleteText(andReplaceWith: FlatEntry.serialize(manyEntries.get(startingAtSecondsSince1970: 86400)))
                ptn.entriesHook.typeKey(.enter)
                clickStatusMenu()
            }
            let project1Header = HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: "project 1").headerLabel
            group("Open daily report") {
                clickStatusMenu(with: .maskAlternate)
                wait(for: "daily report to open", until: {project1Header.exists})
            }
            group("Scroll to project 1") {
                let project25Header = HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: "project 25").headerLabel
                
                XCTAssertTrue(project25Header.isVisible)
                XCTAssertFalse(project1Header.isVisible)
                
                project1Header.hover()
                XCTAssertFalse(project25Header.isVisible)
                XCTAssertTrue(project1Header.isVisible)
            }
        }
    }
    
    func testFocus() {
        let ptn = openPtn()
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
            XCTAssertFalse(ptn.window.isVisible)
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
    
    /// Similar to `testPreferences`, but specific to PTN frequency prefs.
    /// I'm keeping it separate so I don't have to much with adjusting dates in the other schedule-related tests already in that method.
    func testPreferencesForPtnFrequency() {
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
        group("Scheduling") {
            // Because the jitter is random, we're going to take a statistical approach to these.
            //
            // For the no-jitter variant, we'll try 6 times. If there's 1 minute of jitter, the chance of any
            // one iteration succeeding is 50%, and the chance of all 10 succeeding is 0.5^6 = 1.56%.
            // If there's 2 minutes of jitter, the chance of any one iteration succeeding (ie, randomly having
            // no jitter) is 30%, and the chance of all 10 succeeding is 0.0017%.
            //
            // For the with-jitter variant, we'll try up to 10 times with 5 minutes of jitter, which means
            // jitter is anywhere from -5 to +5: 11 values. The chance of randomly hitting jitter >= 0 is 54.54%
            // and the chance of doing that 20 times in a row is 0.000543%.
            var minutesSinceUtc = 0
            group("Setup: 10-minute schedule") {
                frequencyText.deleteText(andReplaceWith: "10\r")
                jitterText.deleteText(andReplaceWith: "0\r")
                XCTAssertEqual("10", frequencyText.stringValue)
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
            }
            group("No jitter") {
                for i in 0..<6 {
                    group("Iteration \(i)") {
                        minutesSinceUtc += 10
                        let secondsSinceUtc = minutesSinceUtc * 60
                        setTimeUtc(s: secondsSinceUtc - 1)
                        pauseToLetStabilize()
                        XCTAssertNil(openWindow)
                        setTimeUtc(s: secondsSinceUtc)
                        waitForTransition(of: .ptn, toIsVisible: true)
                        clickStatusMenu()
                        waitForTransition(of: .ptn, toIsVisible: false)
                    }
                }
            }
            group("Large jitter") {
                group("Setup") {
                    clickStatusMenu()
                    prefsButton.click()
                    XCTAssertTrue(prefsSheet.isVisible)
                    jitterText.deleteText(andReplaceWith: "5\r")
                    clickStatusMenu()
                    waitForTransition(of: .ptn, toIsVisible: false)
                }
                for i in 0..<20 {
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
                            // ne sure to get the PTN, and then close it and try again.
                            minutesSinceUtc += 10
                            setTimeUtc(m: minutesSinceUtc)
                            waitForTransition(of: .ptn, toIsVisible: true)
                            clickStatusMenu()
                            waitForTransition(of: .ptn, toIsVisible: false)
                            return false
                        }
                    }
                    if foundPtn {
                        break
                    }
                }
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
                    timePicker.click()
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
                    clickStatusMenu()
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
                        setTimeUtc(d: 1, h: 16, m: 0, onSessionPrompt: .startNewSession)
                        waitForTransition(of: .dailyEnd, toIsVisible: true)
                        clickStatusMenu() // close the daily report
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
                    timePicker.click()
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
                XCTAssertFalse(ptn.window.isVisible)
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
                XCTAssertTrue(ptn.window.isVisible)
                ptn.window.typeKey(.escape, modifierFlags: [])
                waitForTransition(of: .ptn, toIsVisible: false)
            }
        }
    }
    
    func testDailyReportResizing() {
        let longProjectName = "The quick brown fox jumped over the lazy dog because the dog was just so lazy. Poor dog."
        group("Set up event with long title") {
            let entries = FlatEntry.serialize(entry(
                longProjectName,
                "Some task",
                "Some notes",
                from: Date(timeIntervalSince1970: 43200), // 12 hours
                to: Date(timeIntervalSince1970: 44200)))
            let ptn = openPtn()
            ptn.entriesHook.click()
            ptn.window.typeText(entries + "\r")
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        let originalWindowFrame = group("Open report in two days") {() -> CGRect in
            dragStatusMenu(to: NSScreen.main!.frame.maxX)
            setTimeUtc(d: 2, onSessionPrompt: .startNewSession)
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
                e.hover()
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
            XCTAssertFalse(ptn.window.isVisible)
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
    func setTimeUtc(d: Int = 0, h: Int = 0, m: Int = 0, s: Int = 0, deactivate: Bool = false, onSessionPrompt: LongSessionAction = .ignorePrompt) {
        group("setting time \(d)d \(h)h \(m)m \(s)s") {
            activate(andClickActivatorStatusItem: true)
            let epochSeconds = d * 86400 + h * 3600 + m * 60 + s
            let text = "\(epochSeconds)\r"
            let mockedClockWindow = app.windows["Mocked Clock"]
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
            } else {
                handleLongSessionPrompt(onSessionPrompt)
            }
        }
    }
    
    func checkLongSessionPrompt(exists: Bool) {
        if exists {
            let ptn = findPtn()
            wait(for: "long session prompt", until: {ptn.window.exists && ptn.window.sheets.count > 0})
        } else {
            log("Waiting for a bit, in case a long session prompt is about to come up")
            sleep(1)
            XCTAssertEqual(0, openWindow?.sheets.count)
        }
    }
    
    func handleLongSessionPrompt(_ action: LongSessionAction) {
        let ptn = app.windows[WindowType.ptn.windowTitle]
        if ptn.exists && ptn.sheets.count > 0 {
            switch action {
            case .continueWithCurrentSession:
                ptn.sheets.buttons["Continue with current session"].click()
            case .startNewSession:
                ptn.sheets.buttons["Start new session"].click()
            case .ignorePrompt:
                break // nothing
            }
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
    
    var openWindow: XCUIElement? {
        for windowType in WindowType.allCases {
            let maybe = app.windows[windowType.windowTitle]
            if maybe.exists {
                return maybe
            }
        }
        return nil
    }
    
    func pauseToLetStabilize() {
        sleepMillis(250)
    }
    
    func type(into app: XCUIElement, _ entry: FlatEntry) {
        app.comboBoxes["pcombo"].children(matching: .textField).firstMatch.click()
        app.typeText("\(entry.project)\r\(entry.task)\r\(entry.notes ?? "")\r")
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
    
    func isWindowVisible(_ window: WindowType) -> Bool {
        let visible = app.windows.matching(.window, identifier: window.windowTitle).firstMatch.isVisible
        log("↳ \(String(describing: window)) \(visible ? "is visible" : "is not visible")")
        return visible
    }
    
    class EntriesBuilder {
        private var _entries = [(p: String, t: String, n: String, duration: TimeInterval)]()
        
        @discardableResult func add(project: String, task: String, notes: String, minutes: Double) -> EntriesBuilder {
            _entries.append((p: project, t: task, n: notes, duration: minutes * 60.0))
            return self
        }
        
        func get(startingAtSecondsSince1970 start: Int = 0) -> [FlatEntry] {
            let totalInterval = _entries.map({$0.duration}).reduce(0, +)
            var startTime = Date(timeIntervalSince1970: Double(start) - totalInterval)
            var flatEntries = [FlatEntry]()
            for e in _entries {
                let from = startTime
                let to = startTime.addingTimeInterval(e.duration)
                flatEntries.append(FlatEntry(from: from, to: to, project: e.p, task: e.t, notes: e.n))
                startTime = to
            }
            return flatEntries
        }
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
        case ignorePrompt
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
        
        var windowTitle: String {
            switch self {
            case .ptn:
                return "What are you working on?"
            case .dailyEnd:
                return "Here's what you've been doing"
            }
        }
    }
}
