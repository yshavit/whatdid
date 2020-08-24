// whatdid?

import XCTest
@testable import whatdid

class ComponentUITests: XCTestCase {

    private var app: XCUIApplication!
    
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }
    
    var window: XCUIElement {
        return app.windows["uitestwindow"]
    }
    
    private func use(_ name: String) {
        window.popUpButtons["componentselector"].click()
        window.menuItems[name].click()
    }

    func testButtonWithClosure() {
        use("ButtonWithClosure")
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
    
    func testAutocomplete() {
        use("Autocomplete")
    }
}
