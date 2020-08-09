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
        let ptn = app.windows["What are you working on?"]
        if !ptn.isVisible {
            clickStatusMenu()
        }
        XCTAssertTrue(ptn.isVisible)
        return ptn
    }
    
    func clickStatusMenu(){
        app.menuBars.statusItems["✐"].click()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
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
    
    func entry(_ project: String, _ task: String, _ notes: String?) -> FlatEntry {
        return entry(project, task, notes, from: t(0), to: t(0))
    }
    
    func entry(_ project: String, _ task: String, _ notes: String?, from: Date, to: Date) -> FlatEntry {
        return FlatEntry(from: from, to: to, project: project, task: task, notes: notes)
    }
    
    func t(_ timeDelta: TimeInterval) -> Date {
        return PtnViewControllerTest.SOME_TIME.addingTimeInterval(timeDelta)
    }
}
