// whatdid?

import XCTest
@testable import whatdid

class whatdidUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    func testButtonWithClosure() {
        let app = XCUIApplication()
        app.launchArguments = [DebugMode.buttonWithClosure.toLaunchArgument()]
        app.launch()
        
        let window = XCUIApplication().windows["UI Test Window"]
        let button = window.buttons["Button"]
        let createdLabels = window.staticTexts.matching(NSPredicate(format: "label CONTAINS 'pressed on self'"))
        XCTAssertEqual(createdLabels.count, 0)
        
        button.click()
        XCTAssertEqual(createdLabels.count, 1)
        XCTAssertEqual(
            ["count=1, pressed on self=true"],
            createdLabels.allElementsBoundByIndex.map({$0.label}))
        
        button.click()
        XCTAssertEqual(createdLabels.count, 2)
        XCTAssertEqual(
            ["count=1, pressed on self=true", "count=2, pressed on self=true"],
            createdLabels.allElementsBoundByIndex.map({$0.label}))
    }
}
