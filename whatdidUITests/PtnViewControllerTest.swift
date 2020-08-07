// whatdidUITests?

import XCTest
@testable import whatdid

class PtnViewControllerTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testTabAndEnterBehavior() throws {
        let app = XCUIApplication()
        app.menuBars.statusItems["✐"].click()
        
        let ptn = app.windows["What are you working on?"]
        
        // Let's start with tabs.
        //---------------------------------------------------------------------
        
        // Hitting "enter" in the project should take us to the task
        ptn/*@START_MENU_TOKEN@*/.comboBoxes["pcombo"]/*[[".comboBoxes[\"project\"]",".comboBoxes[\"pcombo\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.typeText("one\t")
        XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus())
        
        // Hitting "enter" in the task field should take us to the notes
        ptn.comboBoxes["tcombo"].typeText("two\t")
        XCTAssertTrue(ptn.textFields["nfield"].hasFocus())
        
        
        // Now backtab back to the project combo
        //---------------------------------------------------------------------
        
        // Now let's hit the backtab and see if we get back to the tasks
        ptn.textFields["nfield"].backtab()
        XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus())
        
        // Backtab again to get to the project
        ptn.comboBoxes["tcombo"].backtab()
        XCTAssertTrue(ptn.comboBoxes["pcombo"].hasFocus())
        
        // And now go forward again, this time with the enter key.
        //---------------------------------------------------------------------
        
        // Hitting "enter" in the project should take us to the task
        ptn/*@START_MENU_TOKEN@*/.comboBoxes["pcombo"]/*[[".comboBoxes[\"project\"]",".comboBoxes[\"pcombo\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.typeText("one\r")
        XCTAssertTrue(ptn.comboBoxes["tcombo"].hasFocus())
        
        // Hitting "enter" in the task field should take us to the notes
        ptn.comboBoxes["tcombo"].typeText("two\r")
        XCTAssertTrue(ptn.textFields["nfield"].hasFocus())
    }
}
