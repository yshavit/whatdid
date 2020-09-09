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

        // The 0.5 isn't necessary, but it positions the cursor in the middle of the item. Just looks nicer.
        app.menuBars.statusItems["✐"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).hover()
        statusItemPoint = CGEvent(source: nil)?.location
        let now = Date()
        log("Failed at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
    }
    
    override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
        let now = Date()
        log("Failed at \(now.utcTimestamp) (\(now.timestamp(at: TimeZone(identifier: "US/Eastern")!)))")
        
        add(XCTAttachment(screenshot: XCUIScreen.main.screenshot()))
        super.recordFailure(withDescription: description, inFile: filePath, atLine: lineNumber, expected: expected)
    }
    
    func openPtn(andThen afterAction: (XCUIElement) -> () = {_ in }) -> Ptn {
        return group("open PTN") {
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
            let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
            for eventType in [CGEventType.leftMouseDown, CGEventType.leftMouseUp] {
                let event = CGEvent(mouseEventSource: src, mouseType: eventType, mouseCursorPosition: statusItemPoint, mouseButton: .left)
                event?.flags = flags
                event?.post(tap: CGEventTapLocation.cghidEventTap)
                pauseToLetStabilize()
            }
        }
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }
    
    func testScheduling() {
        let ptn = app.windows[WindowType.ptn.windowTitle]
        
        // Note: Time starts at 02:00:00 local
        group("basic PTN scheduling") {
            setTimeUtc(h: 0, m: 5) // 02:05; too soon for the popup
            pauseToLetStabilize()
            assertThat(window: .ptn, isVisible: false)
            setTimeUtc(h: 0, m: 55) // 02:55; enough time for the popup
            waitForTransition(of: .ptn, toIsVisible: true)
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
            XCTAssertEqual(["4:30 am", "5:00 am", "5:30 am"], snoozeOptionLabels)
            ptn.menuItems["5:30 am"].click()
            
            // To go 03:29+0200, and the PTN should still be hidden
            
            setTimeUtc(h: 3, m: 29)
            waitForTransition(of: .ptn, toIsVisible: false)

            // But one more minute, and it is visible again
            setTimeUtc(h: 3, m: 31)
            waitForTransition(of: .ptn, toIsVisible: true)
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
            app.activate()
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
    
    func testAutoComplete() {
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
        let dailyReport = app.windows["Here's what you've been doing"]
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
        let ptn = findPtn()
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
            ptn.window.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(ptn.window.isVisible)
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
        }
    }
    
    func testFieldClearingOnPopup() {
        let ptn = openPtn()
        group("Type project, then abandon") {
            XCTAssertTrue(ptn.pcombo.hasFocus)
            app.typeText("project a\r")
            clickStatusMenu()
            XCTAssertFalse(ptn.window.isVisible)
        }
        group("Type task, then abandon") {
            clickStatusMenu()
            XCTAssertTrue(ptn.tcombo.hasFocus)
            app.typeText("task b\r")
            clickStatusMenu()
            XCTAssertFalse(ptn.window.isVisible)
        }
        group("Enter notes") {
            clickStatusMenu()
            XCTAssertTrue(ptn.nfield.hasFocus)
            app.typeText("notes c\r")
            XCTAssertFalse(ptn.window.isVisible)
        }
        group("Reopen PTN") {
            clickStatusMenu()
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
    func setTimeUtc(d: Int = 0, h: Int = 0, m: Int = 0, deactivate: Bool = false, onSessionPrompt: LongSessionAction = .ignorePrompt) {
        group("setting time \(d)d \(h)h \(m)m") {
            app.activate() // bring the clockTicker back, if needed
            let epochSeconds = d * 86400 + h * 3600 + m * 60
            let text = "\(epochSeconds)\r"
            let clockTicker = app.windows["Mocked Clock"].children(matching: .textField).element
            if deactivate {
                app.windows["Mocked Clock"].checkBoxes["Defer until deactivation"].click()
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
            XCTAssertEqual(0, ptnOrDailyReportWindow.sheets.count)
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

    func pressHotkeyShortcut() {
        // 7 == "x"
        for keyDown in [true, false] {
            let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
            let keyEvent = CGEvent(keyboardEventSource: src, virtualKey: 7, keyDown: keyDown)
            keyEvent!.flags = [.maskCommand, .maskShift]
            keyEvent?.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }
    
    var ptnOrDailyReportWindow: XCUIElement {
        for windowType in WindowType.allCases {
            let maybe = app.windows[windowType.windowTitle]
            if maybe.exists {
                return maybe
            }
        }
        XCTFail("Couldn't find PTN or daily report window")
        return nil!
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
