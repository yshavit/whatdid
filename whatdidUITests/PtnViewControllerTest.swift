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
    
    func openPtn() -> XCUIElement {
        let ptn = app.windows["What are you working on?"]
        if !ptn.isVisible {
            app.menuBars.statusItems["✐"].click()
        }
        XCTAssertTrue(ptn.isVisible)
        return ptn
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }
    
    func testKeyboardNavigation() {
        let ptn: XCUIElement = XCTContext.runActivity(named: "open PTN") {_ in
            let res = self.openPtn()
            XCTAssertFalse(res.comboBoxes["tcombo"].hasFocus()) // Sanity check that hasFocus() doesn't always return true :)
            return res
        }
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
