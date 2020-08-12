// whatdidUITests?

import XCTest
@testable import whatdid

class PtnViewControllerTest: XCTestCase {
    private static let SOME_TIME = Date()
    private var app : XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func openPtn(andThen afterAction: (XCUIElement) -> () = {_ in }) -> XCUIElement {
        return XCTContext.runActivity(named: "open PTN") {_ in
            let ptn = openPtnNotInActivity()
            afterAction(ptn)
            return ptn
        }
    }
    
    func openPtnNotInActivity() -> XCUIElement {
        let ptn = app.windows[WindowType.ptn.windowTitle]
        if !ptn.isVisible {
            clickStatusMenu()
        }
        assertThat(window: .ptn, isVisible: true)
        return ptn
    }
    
    func clickStatusMenu(){
        app.menuBars.statusItems["✐"].click()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }
    
    func testScheduling() {
        let ptn = app.windows[WindowType.ptn.windowTitle]
        
        // Note: Time starts at 02:00:00 local
        XCTContext.runActivity(named: "basic PTN scheduling") {_ in
            setTimeUtc(h: 0, m: 5) // 02:05; too soon for the popup
            XCTAssertFalse(ptn.isVisible)
            setTimeUtc(h: 0, m: 55) // 02:55; enough time for the popup
            assertThat(window: .ptn, isVisible: true)
        }
        XCTContext.runActivity(named: "snooze button: standard press") {_ in
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
        XCTContext.runActivity(named: "snooze button: extra options") {_ in
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
        
        XCTContext.runActivity(named: "daily report (no contention with PTN)") {_ in
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
        XCTContext.runActivity(named: "daily report (with contention with PTN)") {_ in
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
    
    // TODO: also test with just typing (not downarrow)
    func testAutoComplete() {
        let ptn = openPtn()
        XCTContext.runActivity(named: "initalize the data") {_ in
            let entriesTextField  = ptn.textFields["uihook_flatentryjson"]
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
        XCTContext.runActivity(named: "autocomplete wh*") {_ in
            let pcombo = ptn.comboBoxes["pcombo"]
            pcombo.click()
            pcombo.typeKey(.downArrow)
            pcombo.typeText("\r")
            XCTAssertEqual("whodid", pcombo.stringValue)
        }
    }
    
    func testKeyboardNavigation() {
        // Get the PTN, and do a sanity check that hasFocus() doesn't always return true :)
        let ptn = openPtn(andThen: {XCTAssertFalse($0.comboBoxes["tcombo"].hasFocus)})
        XCTContext.runActivity(named: "forward tabbing") {_ in
            XCTAssertTrue(ptn.comboBoxes["pcombo"].hasFocus) // Sanity check
            // Tab from Project -> Task
            ptn.focusedChild.typeKey(.tab)
            XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus)
            // Tab from Task -> Notes
            ptn.focusedChild.typeKey(.tab)
            XCTAssertTrue(ptn.textFields["nfield"].hasFocus)
        }
        XCTContext.runActivity(named: "backward tabbing") {_ in
            XCTAssertTrue(ptn.textFields["nfield"].hasFocus) // Sanity check
            // Backtab from Notes to Task
            ptn.focusedChild.typeKey(.tab, modifierFlags: .shift)
            XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus)
            // Backtab from Task to Project
            ptn.focusedChild.typeKey(.tab, modifierFlags: .shift)
            XCTAssertTrue(ptn.comboBoxes["pcombo"].hasFocus)
        }
        XCTContext.runActivity(named: "enter key") {_ in
            XCTAssertTrue(ptn.comboBoxes["pcombo"].hasFocus) // Sanity check
            // Enter from Project to Task
            ptn.comboBoxes["pcombo"].typeKey(.enter)
            XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus)
            // Enter from Task to Notes
            ptn.comboBoxes["pcombo"].typeKey(.enter)
            XCTAssertTrue(ptn.textFields["nfield"].hasFocus)
        }
        XCTContext.runActivity(named: "escape key") {_ in
            ptn.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(ptn.isVisible)
        }
    }
    
    func setTimeUtc(d: Int = 0, h: Int = 0, m: Int = 0) {
        app.activate() // bring the clockTicker back, if needed
        let text = "\(d * 86400 + h * 3600 + m * 60)\r"
        let clockTicker = app.windows["Mocked Clock"].children(matching: .textField).element
        clockTicker.deleteText(andReplaceWith: text)
    }
    
    func assertThat(window: WindowType, isVisible expected: Bool) {
        XCTAssertEqual(expected ? 1 : 0, app.windows.matching(.window, identifier: window.windowTitle).count)
    }
    
    func type(into ptn: XCUIElement, _ entry: FlatEntry) {
        ptn.comboBoxes["pcombo"].click()
        app.typeText("\(entry.project)\r\(entry.task)\r\(entry.notes ?? "")\r")
    }
    
    func entry(_ project: String, _ task: String, _ notes: String?) -> FlatEntry {
        return entry(project, task, notes, from: t(0), to: t(0))
    }
    
    func entry(_ project: String, _ task: String, _ notes: String?, from: Date, to: Date) -> FlatEntry {
        return FlatEntry(from: from, to: to, project: project, task: task, notes: notes)
    }
    
    func t(_ timeDelta: TimeInterval) -> Date {
        return PtnViewControllerTest.SOME_TIME.addingTimeInterval(timeDelta)
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
