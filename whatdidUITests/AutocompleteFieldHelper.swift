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

    var hasFocus: Bool {
        return textField.hasFocus
    }

    var optionTextFieldsQuery: XCUIElementQuery {
        optionsScroll.children(matching: .textField)
    }
    
    /// The available options; fails if the options pane is not open
    ///
    /// This computed property is slow if there are many options.
    var optionTextFieldsByIndex: [XCUIElement] {
        optionTextFieldsQuery.allElementsBoundByIndex
    }
    
    /// A faster variant of `optionTextFields[index]`
    func optionTextField(atIndex index: Int) -> XCUIElement {
        return optionsScroll.children(matching: .textField).element(boundBy: index)
    }
    
    /// The available options' string values; fails if the options pane is not open.
    ///
    /// This computed property is slow if there are many options.
    var optionTextStrings: [String] {
        return XCTestCase.group("Find option text field strings") {
            optionTextFieldsByIndex.map { $0.stringValue }
        }
    }
    
    private var selectedOptions: [String] {
        optionTextFieldsQuery.matching(NSPredicate(format: "isSelected = true"))
            .allElementsBoundByIndex
            .map{$0.stringValue}
    }
    
    /// The options pane is open, but no field is selected
    func assertNoOptionSelected() {
        return XCTestCase.group("Look for no selected options") {
            XCTAssertEqual([], selectedOptions)
        }
    }
    
    /// The selected option's string value; fails if the options pane is not open
    var selectedOptionText: String {
        return XCTestCase.group("Find the selected option") {
            let selecteds = selectedOptions
            XCTAssertEqual(1, selecteds.count, "expected exactly one selected option")
            return selecteds[0]
        }
    }
}
