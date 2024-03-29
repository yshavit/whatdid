// whatdidUITests?

import XCTest

struct AutocompleteFieldHelper {
    let element: XCUIElement
    private var origButtonHeight: CGFloat
    
    init(element: XCUIElement) {
        self.element = element
        origButtonHeight = -1 // need to init this so we can use the "button" computed property
        origButtonHeight = button.frame.height
    }
    
    /// The editable text field
    var textField: XCUIElement {
        element
    }
    
    /// The popup button that toggles the options pane
    var button: XCUIElement {
        return element.children(matching: .button).element
    }
    
    /// The options pane, or fail if it is not open
    var optionsScroll: XCUIElement {
        return XCTestCase.group("FieldHelper: fetch optionsScroll") {
            let allScrolls = element.children(matching: .scrollView).allElementsBoundByIndex
            XCTAssertEqual(1, allScrolls.count, "Expected exactly one options pane")
            return allScrolls[0]
        }
    }
    
    var optionsScrollIsOpen: Bool {
        return XCTestCase.group("FieldHelper: fetch optionsScroll") {
            switch element.children(matching: .scrollView).allElementsBoundByIndex.count {
            case 0:
                return false
            case 1:
                return true
            default:
                XCTFail("expected 0 or 1 optionsScrolls")
                return false
            }
        }
    }
    
    func assertOptionsPaneHidden() {
        XCTAssertEqual(0, element.children(matching: .scrollView).count)
    }
    
    /// The options pane is open but empty
    func assertOptionsOpenButEmpty() {
        XCTestCase.group("FieldHelper: assertOptionsOpenButEmpty") {
            XCTAssertEqual(0, optionsScroll.children(matching: .textField).count)
        }
    }
    
    func checkOptionsScrollFrameHeight() {
        let textFieldFrame = textField.frame
        let optionsScrollFrame = optionsScroll.frame
        let buttonFrame = button.frame
        XCTAssertEqual(textFieldFrame.minY.rounded(.down), buttonFrame.minY.rounded(.down))
        XCTAssertEqual(origButtonHeight.rounded(.down), buttonFrame.height.rounded(.down))
        XCTAssertEqual(textFieldFrame.maxY.rounded(.down) + 2, optionsScrollFrame.minY.rounded(.down))
    }

    var hasFocus: Bool {
        return textField.hasFocus
    }

    var optionTextFieldsQuery: XCUIElementQuery {
        return optionsScroll.descendants(matching: .textField)
    }
    
    /// The available options; fails if the options pane is not open
    ///
    /// This computed property is slow if there are many options.
    var optionTextFieldsByIndex: [XCUIElement] {
        optionTextFieldsQuery.allElementsBoundByIndex
    }
    
    /// A faster variant of `optionTextFields[index]`
    func optionTextField(atIndex index: Int) -> XCUIElement {
        return optionsScroll.descendants(matching: .textField).element(boundBy: index)
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
