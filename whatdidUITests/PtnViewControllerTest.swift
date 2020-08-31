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
                usleep(250000)
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
            XCTAssertFalse(ptn.isVisible)
            setTimeUtc(h: 0, m: 55) // 02:55; enough time for the popup
            assertThat(window: .ptn, isVisible: true)
        }
        group("snooze button: standard press") {
            // Note: PTN is still up at this point.
            let button = ptn.buttons["snoozebutton"]
            // It's 02:55 now, so we add 15 minutes and then round to the next highest half-hour. That means
            // the default snooze is 3:30.
            // Trim whitespace, since we put some in so it aligns well with the snoozeopts button
            XCTAssertEqual("Snooze until 3:30 am", button.title.trimmingCharacters(in: .whitespaces))
            button.click()
            assertThat(window: .ptn, isVisible: false)
            
            // To go 03:29+0200, and the PTN should still be hidden
            setTimeUtc(h: 1, m: 29)
            assertThat(window: .ptn, isVisible: false)

            // But one more minute, and it is visible again
            setTimeUtc(h: 1, m: 31)
            assertThat(window: .ptn, isVisible: true)
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
            assertThat(window: .ptn, isVisible: false)

            // But one more minute, and it is visible again
            setTimeUtc(h: 3, m: 31)
            assertThat(window: .ptn, isVisible: true)
        }
        
        group("daily report (no contention with PTN)") {
            // Note: PTN is still up at this point. It's currently 05:31+0200.
            // We'll bring it to 18:29, and then dismiss it.
            // Then the next minute, there should be the daily report
            setTimeUtc(h: 16, m: 29)
            type(into: app, entry("my project", "my task", "my notes"))
            assertThat(window: .ptn, isVisible: false)
            
            setTimeUtc(h: 16, m: 30)
            assertThat(window: .ptn, isVisible: false)
            app.activate()
            assertThat(window: .dailyEnd, isVisible: true)
            clickStatusMenu() // close the report
            assertThat(window: .dailyEnd, isVisible: false)
        }
        group("daily report (with contention with PTN)") {
            // Fast-forward a day. At 18:29 local, we should get a PTN.
            // Wait two minutes (so that the daily report is due) and then type in an entry.
            // We should get the daily report next, which we should then be able to dismiss.
            setTimeUtc(d: 1, h: 16, m: 29)
            assertThat(window: .ptn, isVisible: true)
            
            setTimeUtc(d: 1, h: 16, m: 31)
            assertThat(window: .dailyEnd, isVisible: false)
            assertThat(window: .ptn, isVisible: true)
            
            type(into: app, entry("my project", "my task", "my notes"))
            assertThat(window: .ptn, isVisible: false)
            assertThat(window: .dailyEnd, isVisible: true)
            
            clickStatusMenu() // close the daily report
            assertThat(window: .dailyEnd, isVisible: false)
            // Also wait a second, so that we can be sure it didn't pop back open (GH #72)
            Thread.sleep(forTimeInterval: 1)
            assertThat(window: .dailyEnd, isVisible: false)
        }
    }
    
    func testAutoComplete() {
        let ptn = openPtn()
        group("initalize the data") {
            let entriesTextField  = ptn.window.textFields["uihook_flatentryjson"]
            // Three entries, in shuffled alphabetical order (neither fully ascending or descending)
            // We want both the lowest and highest values (alphanumerically) to be in the middle.
            // That means that when we autocomplete "wh*", we can be sure that we're getting date-ordered
            // entries.
            let entriesSerialized = FlatEntry.serialize(
                entry("wheredid", "something else", "notes 2", from: t(-100), to: t(-90)),
                entry("whatdid", "autothing", "notes 1", from: t(-80), to: t(-70)),
                entry("whytdid", "autothing", "notes 1", from: t(-80), to: t(-70)),
                entry("whodid", "something else", "notes 2", from: t(-60), to: t(-50)))
            entriesTextField.click()
            entriesTextField.typeText(entriesSerialized + "\r")
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
        group("Initalize the data") {
            let ptn = openPtn()
            let entriesTextField  = ptn.window.textFields["uihook_flatentryjson"]
            let entries = EntriesBuilder()
                .add(project: "project a", task: "task 1", notes: "first thing", minutes: 10)
                .add(project: "project a", task: "task 2", notes: "sidetrack", minutes: 15)
                .add(project: "project a", task: "task 1", notes: "back to first", minutes: 5)
                .add(project: "project b", task: "task same", notes: "fizz", minutes: 5)
                .add(project: "project c", task: "task same", notes: "fuzz", minutes: 10)
                .serialize()
            entriesTextField.deleteText(andReplaceWith: entries)
            entriesTextField.typeKey(.enter)
            clickStatusMenu()
        }
        let dailyReport = app.windows["Here's what you've been doing"]
        group("Open daily report") {
            clickStatusMenu(with: .maskAlternate)
            XCTAssertTrue(dailyReport.isVisible)
        }
        group("Verify projects exist") {
            for project in ["project a", "project b", "project c"] {
                group(project) {
                    for (description, e) in HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: project).allElements {
                        XCTAssertTrue(e.exists, "\"\(project)\" \(description)")
                    }
                }
            }
        }
        group("Verify projects visible") {
            for project in ["project a", "project b", "project c"] {
                group(project) {
                    for (description, e) in HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: project).allElements {
                        XCTAssertTrue(e.isHittable, "\"\(project)\" \(description)")
                    }
                }
            }
        }
    }
    
    func testKeyboardNavigation() {
        let ptn = findPtn()
        group("Hot key grabs focus with PTN open") {
            setTimeUtc(h: 01, m: 00, deactivate: true)
            pressHotkeyShortcut()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
            group("Type text to check focus") {
                ptn.pcombo.textField.typeText("hello 1")
                XCTAssertEqual("hello 1", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.deleteText()
            }
        }
        group("Hot key opens focus") {
            group("Close PTN") {
                clickStatusMenu() // close the app
                activateFinder()
            }
            pressHotkeyShortcut()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
            group("Type text to check focus") {
                ptn.pcombo.textField.typeText("hello 2")
                XCTAssertEqual("hello 2", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.deleteText()
            }
        }
        group("Status menu grabs focus when app is not active") {
            group("Close PTN") {
                clickStatusMenu() // close the app
                XCTAssertFalse(ptn.window.isVisible)
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
    
    func setTimeUtc(d: Int = 0, h: Int = 0, m: Int = 0, deactivate: Bool = false) {
        group("setting time \(d)d \(h)h \(m)m") {
            app.activate() // bring the clockTicker back, if needed
            let text = "\(d * 86400 + h * 3600 + m * 60)\r"
            let clockTicker = app.windows["Mocked Clock"].children(matching: .textField).element
            if deactivate {
                app.windows["Mocked Clock"].checkBoxes["Defer until deactivation"].click()
            }
            clockTicker.deleteText(andReplaceWith: text)
            if deactivate {
                activateFinder()
            }
        }
    }
    
    func activateFinder() {
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

    func pressHotkeyShortcut() {
        // 7 == "x"
        for keyDown in [true, false] {
            let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
            let keyEvent = CGEvent(keyboardEventSource: src, virtualKey: 7, keyDown: keyDown)
            keyEvent!.flags = [.maskCommand, .maskShift]
            keyEvent?.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }
    
    func assertThat(window: WindowType, isVisible expected: Bool) {
        XCTAssertEqual(expected ? 1 : 0, app.windows.matching(.window, identifier: window.windowTitle).count)
    }
    
    func type(into app: XCUIElement, _ entry: FlatEntry) {
        app.comboBoxes["pcombo"].children(matching: .textField).firstMatch.click()
        app.typeText("\(entry.project)\r\(entry.task)\r\(entry.notes ?? "")\r")
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
    
    class EntriesBuilder {
        private var entries = [(p: String, t: String, n: String, duration: TimeInterval)]()
        
        func add(project: String, task: String, notes: String, minutes: Double) -> EntriesBuilder {
            entries.append((p: project, t: task, n: notes, duration: minutes * 60.0))
            return self
        }
        
        func serialize(now: Date? = nil) -> String {
            let totalInterval = entries.map({$0.duration}).reduce(0, +)
            var startTime = t(-totalInterval)
            var flatEntries = [FlatEntry]()
            for e in entries {
                let from = startTime
                let to = startTime.addingTimeInterval(e.duration)
                flatEntries.append(FlatEntry(from: from, to: to, project: e.p, task: e.t, notes: e.n))
                startTime = to
            }
            return FlatEntry.serialize(flatEntries)
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
    }
    
    struct Ptn {
        let window: XCUIElement
        let pcombo: AutocompleteFieldHelper
        let tcombo: AutocompleteFieldHelper
        
        var nfield: XCUIElement {
            window.textFields["nfield"]
        }
    }
    
    enum WindowType {
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
