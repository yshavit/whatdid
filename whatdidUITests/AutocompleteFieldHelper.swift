// whatdidUITests?

import XCTest

struct AutocompleteFieldHelper {
    let element: XCUIElement
    
    /// The editable text field
    var textField: XCUIElement {
        return element.children(matching: .textField).element
    }
    
    /// The popup button that toggles the options pane
    var button: XCUIElement {
        return element.children(matching: .popUpButton).element
    }
    
    /// The options pane, or `nil` if it is not open
    var optionsScroll: XCUIElement {
        return XCTestCase.group("FieldHelper: fetch optionsScroll") {
            let allScrolls = element.children(matching: .scrollView).allElementsBoundByIndex
            XCTAssertEqual(1, allScrolls.count, "Expected exactly one options pane")
            return allScrolls[0]
        }
    }
    
    func assertOptionsPaneHidden() {
        XCTAssertEqual(0, element.children(matching: .scrollView).count)
    }
    
    /// The options pane is open but empty
    func assertOptionsOpenButEmpty() {
        XCTestCase.group("FieldHelper: assertOptionsOpenButEmpty") {
            XCTAssertEqual(0, optionsScroll.children(matching: .textField).count)
            XCTAssertEqual("(no previous entries)", optionsScroll.staticTexts.element.stringValue)
        }
    }
    
    /// The available options; fails if the options pane is not open
    var optionTextFields: [XCUIElement] {
        optionsScroll.children(matching: .textField).allElementsBoundByIndex
    }
    
    /// The available options' string values; fails if the options pane is not open
    var optionTextStrings: [String] {
        return XCTestCase.group("Find option text field strings") {
            optionTextFields.map { $0.stringValue }
        }
    }
    
    /// The options pane is open, but no field is selected
    func assertNoOptionSelected() {
        return XCTestCase.group("Look for no selected options") {
            XCTAssertEqual([], optionTextFields.filter { $0.isSelected }.map { $0.stringValue })
        }
    }
    
    /// The selected option's string value; fails if the options pane is not open
    var selectedOptionText: String {
        return XCTestCase.group("Find the selected option") {
            let selecteds = optionTextFields.filter { $0.isSelected }.map { $0.stringValue }
            XCTAssertEqual(1, selecteds.count, "expected exactly one selected option")
            return selecteds[0]
        }
    }
}
