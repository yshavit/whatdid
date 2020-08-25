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

        
        let app = XCUIApplication()
        let uitestwindowWindow = app.windows["uitestwindow"]
        let placeholderTextField = uitestwindowWindow.textFields["placeholder"]
        placeholderTextField.click()
        uitestwindowWindow.popUpButtons["Toggle options"].click()
        placeholderTextField.typeKey(.downArrow, modifierFlags:.function)
        placeholderTextField.typeKey(.downArrow, modifierFlags:.function)
        app.scrollViews.staticTexts["three"].click()
        
//        let app = XCUIApplication()
//        let uitestwindowWindow = app/*@START_MENU_TOKEN@*/.windows["uitestwindow"]/*[[".windows[\"UI Test Window\"]",".windows[\"uitestwindow\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
//        uitestwindowWindow.popUpButtons["componentselector"].click()
//        uitestwindowWindow/*@START_MENU_TOKEN@*/.menuItems["Autocomplete"]/*[[".popUpButtons[\"componentselector\"]",".menus.menuItems[\"Autocomplete\"]",".menuItems[\"Autocomplete\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
//
//        let textField = uitestwindowWindow.children(matching: .textField).element(boundBy: 0)
//        textField.click()
//        textField.typeKey("v", modifierFlags:.command)
//        textField.typeText("\r")
//
//        let placeholderTextField = uitestwindowWindow.textFields["placeholder"]
//        placeholderTextField.click()
//        app/*@START_MENU_TOKEN@*/.staticTexts["two"]/*[[".dialogs",".scrollViews.staticTexts[\"two\"]",".staticTexts[\"two\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
//
//        let goDownPopUpButton = uitestwindowWindow.popUpButtons["go down"]
//        goDownPopUpButton.click()
//        app.scrollViews.staticTexts["one"].click()
//        placeholderTextField.typeKey(.downArrow, modifierFlags:.function)
//        placeholderTextField.typeKey(.downArrow, modifierFlags:.function)
//        placeholderTextField.typeKey(.downArrow, modifierFlags:.function)
//        placeholderTextField.typeKey(.downArrow, modifierFlags:.function)
//        placeholderTextField.typeKey(.upArrow, modifierFlags:.function)
//        uitestwindowWindow.click()
//        placeholderTextField.click()
//        placeholderTextField.typeKey(.delete, modifierFlags:[])
//        placeholderTextField.typeText("")
//        placeholderTextField.typeKey(.delete, modifierFlags:.option)
//        goDownPopUpButton.click()
//        app/*@START_MENU_TOKEN@*/.scrollViews.staticTexts["one"]/*[[".dialogs",".scrollViews.staticTexts[\"one\"]",".staticTexts[\"one\"]"],[[[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.click()
//        uitestwindowWindow.click()
        
        
        
        
//    
//        app.menuBars.statusItems["✐"].click()
//        
//        let uihookFlatentryjsonTextField = app.windows["What are you working on?"].textFields["uihook_flatentryjson"]
//        uihookFlatentryjsonTextField.click()
//        uihookFlatentryjsonTextField.typeKey("v", modifierFlags:.command)
//        uihookFlatentryjsonTextField.typeText("\r")
//        
//        let app2 = app!
//        app2.windows["What are you working on?"].buttons["go down"].click()
//        app2.scrollViews.children(matching: .other).matching(identifier: "alpha").element(boundBy: 1).staticTexts["alpha"].click()
//        app2.otherElements["two"].staticTexts["two"].click()
//        
        
    }
}
