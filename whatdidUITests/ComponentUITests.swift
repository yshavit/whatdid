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
    
    var testWindow: XCUIElement {
        return app.windows["uitestwindow"]
    }
    
    private func use(_ name: String) {
        testWindow.popUpButtons["componentselector"].click()
        testWindow.menuItems[name].click()
    }

    func testButtonWithClosure() {
        use("ButtonWithClosure")
        let button = testWindow.buttons["Button"]
        let createdLabels = testWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS 'pressed on self'"))
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
        
//        testWindow.printAccessibilityTree()
        
//        printAccessibilityTree(testWindow)
        let optionsDefinition = testWindow.textFields["test_defineoptions"]
        let autocompleteField = testWindow.comboBoxes["test_autocomplete"]
        let autocompletePopupButton = autocompleteField.children(matching: .popUpButton).element
        let scrollView = autocompleteField.descendants(matching: .scrollView).element
        
        group("empty options without clicking in field first") {
            optionsDefinition.click()
            optionsDefinition.typeText("one,two,three\r")
//            XCTAssertEqual("", optionsDefinition.stringValue) // sanity check
//            XCTAssertEqual("", autocompleteField.stringValue)
//            XCTAssertEqual(0, autocompleteField.children(matching: .scrollView).count)
            autocompleteField.printAccessibilityTree()
//            XCTAssertFalse(scrollView.isVisible)
            autocompletePopupButton.click()
            autocompleteField.printAccessibilityTree()
            XCTAssertTrue(scrollView.isVisible)
        }
        
        /**
         This is how a normal NSComboBox works:
         
         ```
         let pcomboComboBox = app.windows["What are you working on?"].comboBoxes["pcombo"]
         pcomboComboBox.click()
         pcomboComboBox.typeText("one\r")
         pcomboComboBox.children(matching: .button).element.click()
         
         pcomboComboBox.scrollViews.otherElements.children
          
         ptn.textFields["nfield"].typeText("\r")(matching: .textField).element(boundBy: 0).click()
         ```
         
         See:
         - [The OS X Accessibility Model][1]
         - [NSAccessibilityProtocol][2]
         - [accessibilityAddChildElement][3]
         
         [1]: https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXmodel.html
         [2]: https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol
         [3]: https://developer.apple.com/documentation/appkit/nsaccessibilityelement/1533717-accessibilityaddchildelement
         */
        
        
        
        
        
//        optionsDefinition.click()
//        optionsDefinition.typeText("one,two")
//
//        autocompleteField.click()
//        let children = autocompleteField.children(matching: .any).allElementsBoundByIndex
//        print(String(repeating: "=", count: 72))
//        for elem in children {
//            print(elem.debugDescription)
//            print(String(repeating: "-", count: 72))
//        }
    }
    
    
}
