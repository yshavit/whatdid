// whatdidUITests?

import XCTest
@testable import whatdid

class PtnViewControllerTest: XCTestCase {
    private var app : XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func openPtn(andThen afterAction: (XCUIElement) -> () = {_ in }) -> XCUIElement {
        return XCTContext.runActivity(named: "open PTN") {_ in
            let ptn = app.windows["What are you working on?"]
            if !ptn.isVisible {
                app.menuBars.statusItems["✐"].click()
            }
            XCTAssertTrue(ptn.isVisible)
            afterAction(ptn)
            return ptn
        }
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }
    
    func testAutoComplete() {
        let ptn = openPtn()
        XCTContext.runActivity(named: "initalize the data") {_ in
            let entriesTextField  = ptn.textFields["uihook_flatentryjson"]
            let entriesSerialized = FlatEntry.serialize(
                FlatEntry(
                    from: Date().addingTimeInterval(-120),
                    to: Date(),
                    project: "my project",
                    task: "my task",
                    notes: "some notes"))
            entriesTextField.replaceTextFieldContents(with: entriesSerialized + "\r")
            
        }
    }
    
    func testKeyboardNavigation() {
        // Get the PTN, and do a sanity check that hasFocus() doesn't always return true :)
        let ptn = openPtn(andThen: {XCTAssertFalse($0.comboBoxes["tcombo"].hasFocus())})
        XCTContext.runActivity(named: "forward tabbing") {_ in
            XCTAssertTrue(ptn.comboBoxes["pcombo"].hasFocus()) // Sanity check
            // Tab from Project -> Task
            ptn.focusedChild.typeKey(.tab)
            XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus())
            // Tab from Task -> Notes
            ptn.focusedChild.typeKey(.tab)
            XCTAssertTrue(ptn.textFields["nfield"].hasFocus())
        }
        XCTContext.runActivity(named: "backward tabbing") {_ in
            XCTAssertTrue(ptn.textFields["nfield"].hasFocus()) // Sanity check
            // Backtab from Notes to Task
            ptn.focusedChild.typeKey(.tab, modifierFlags: .shift)
            XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus())
            // Backtab from Task to Project
            ptn.focusedChild.typeKey(.tab, modifierFlags: .shift)
            XCTAssertTrue(ptn.comboBoxes["pcombo"].hasFocus())
        }
        XCTContext.runActivity(named: "enter key") {_ in
            XCTAssertTrue(ptn.comboBoxes["pcombo"].hasFocus()) // Sanity check
            // Enter from Project to Task
            ptn.comboBoxes["pcombo"].typeKey(.enter)
            XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus())
            // Enter from Task to Notes
            ptn.comboBoxes["pcombo"].typeKey(.enter)
            XCTAssertTrue(ptn.textFields["nfield"].hasFocus())
        }
        XCTContext.runActivity(named: "escape key") {_ in
            ptn.typeKey(.escape, modifierFlags: [])
            XCTAssertFalse(ptn.isVisible)
        }
    }
}
