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
    
    func clickStatusMenu(){
        app.menuBars.statusItems["✐"].click()
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
    
    // TODO: also test with just typing (not downarrow)
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
    
    func testKeyboardNavigation() {
        let ptn = findPtn()// openPtn(andThen: {XCTAssertFalse($0.comboBoxes["tcombo"].hasFocus)})
        
        group("Hot key grabs focus with PTN open") {
            setTimeUtc(h: 01, m: 00, deactivate: true)
            waitForCondition { activeAppBundleId != "com.yuvalshavit.whatdid" }
            app.typeKey("x", modifierFlags: [.command, .shift])
            waitForCondition { activeAppBundleId == "com.yuvalshavit.whatdid" }
            app.typeText("hello 1")
            XCTAssertEqual("hello 1", ptn.pcombo.textField.stringValue)
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
        group("escape key") {
            ptn.window.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(ptn.window.isVisible)
        }
    }
    
    func setTimeUtc(d: Int = 0, h: Int = 0, m: Int = 0, deactivate: Bool = false) {
        app.activate() // bring the clockTicker back, if needed
        let text = "\(d * 86400 + h * 3600 + m * 60)\r"
        let clockTicker = app.windows["Mocked Clock"].children(matching: .textField).element
        if deactivate {
            app.windows["Mocked Clock"].checkBoxes["Deactivate before setting"].click()
        }
        clockTicker.deleteText(andReplaceWith: text)
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
    
    func t(_ timeDelta: TimeInterval) -> Date {
        return PtnViewControllerTest.SOME_TIME.addingTimeInterval(timeDelta)
    }
    
    struct Ptn {
        let window: XCUIElement
        let pcombo: AutocompleteFieldHelper
        let tcombo: AutocompleteFieldHelper
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
