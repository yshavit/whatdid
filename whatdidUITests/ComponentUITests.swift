// whatdid?

import XCTest
@testable import whatdid

class ComponentUITests: XCTestCase {

    private var app: XCUIApplication!
    
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        app.activate()
    }
    
    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }
    
    var testWindow: XCUIElement {
        return app.windows["uitestwindow"]
    }
    
    private func use(_ name: String) {
        group("Select \"\(name)\"") {
            testWindow.popUpButtons["componentselector"].click()
            testWindow.menuItems[name].click()
        }
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
    
    func testAutocompleteEmptyOptions() {
        use("Autocomplete")
        let optionsDefinition = testWindow.textFields["test_defineoptions"]
        let resultField = testWindow.staticTexts["test_result"]
        let fieldHelper = AutocompleteFieldHelper(element: testWindow.comboBoxes["test_autocomplete"])
        
        // Basic show/hide behavior with no autocomplete options
        group("Empty options without clicking in field first") {
            group("check initial state") {
                XCTAssertEqual("", optionsDefinition.stringValue) // sanity check
                XCTAssertEqual("", fieldHelper.textField.stringValue) // sanity check
                fieldHelper.assertOptionsPaneHidden()
            }
            group("Click to show options") {
                fieldHelper.button.click()
                fieldHelper.assertOptionsOpenButEmpty()
            }
            group("Click to hide options") {
                fieldHelper.button.click()
                fieldHelper.assertOptionsPaneHidden()
            }
        }
        group("Clicking in text field keeps options open") {
            group("Click to show options") {
                fieldHelper.button.click()
                fieldHelper.assertOptionsOpenButEmpty()
            }
            group("Click in text field") {
                fieldHelper.textField.click()
                fieldHelper.assertOptionsOpenButEmpty()
                XCTAssertTrue(fieldHelper.textField.hasFocus)
            }
        }
        group("Clicking outside closes the options") {
            fieldHelper.assertOptionsOpenButEmpty() // sanity check that it's still open
            testWindow.click()
            fieldHelper.assertOptionsPaneHidden()
            XCTAssertFalse(fieldHelper.textField.hasFocus)
        }
        // Typing actions
        group("Typing with no autocomplete") {
            group("Click in the text field") {
                fieldHelper.textField.click()
                fieldHelper.assertOptionsOpenButEmpty()
            }
            group("Type some text") {
                testWindow.typeText("hello world")
                XCTAssertEqual("hello world", fieldHelper.textField.stringValue)
                XCTAssertEqual("", resultField.stringValue) // Make sure we don't fire on every key event
            }
            group("Press enter") {
                fieldHelper.textField.typeKey(.enter)
                XCTAssertEqual("hello world", resultField.stringValue)
            }
        }
        // Tabbing options
        group("Forward-tabbing") {
            group("Setup") {
                optionsDefinition.click()
                XCTAssertTrue(optionsDefinition.hasFocus) // sanity check
            }
            group("tab from optionsDefinition to autocomplete") {
                testWindow.typeKey(.tab)
                XCTAssertTrue(fieldHelper.hasFocus)
            }
            group("tab from autocomplete to optionsDefinition") {
                testWindow.typeKey(.tab)
                XCTAssertTrue(optionsDefinition.hasFocus)
            }
            group("backtab from optionsDefinition to autocomplete") {
                testWindow.typeKey(.tab, modifierFlags: .shift)
                XCTAssertTrue(fieldHelper.hasFocus)
            }
            group("backtab from autocomplete to optionsDefinition") {
                testWindow.typeKey(.tab, modifierFlags: .shift)
                XCTAssertTrue(optionsDefinition.hasFocus)
            }
        }
    }
    
    func testAutocompleteAFewOptions() {
        use("Autocomplete")
        let optionsDefinition = testWindow.textFields["test_defineoptions"]
        let resultField = testWindow.staticTexts["test_result"]
        let fieldHelper = AutocompleteFieldHelper(element: testWindow.comboBoxes["test_autocomplete"])

        group("Set up options") {
            optionsDefinition.deleteText(andReplaceWith: "Aaa,Bbb,Ccc,Ddd\r")
        }
        group("All options initially visible") {
            XCTAssertEqual("", fieldHelper.textField.stringValue) // sanity check
            fieldHelper.button.click()
            XCTAssertEqual(["Aaa", "Bbb", "Ccc", "Ddd"], fieldHelper.optionTextStrings)
        }
        group("Match recent option") {
            fieldHelper.textField.deleteText(andReplaceWith: "A")
            XCTAssertEqual(["Aaa", "Bbb", "Ccc"], fieldHelper.optionTextStrings)
            fieldHelper.assertNoOptionSelected()
        }
        group("Match non-recent option") {
            fieldHelper.textField.deleteText(andReplaceWith: "D")
            XCTAssertEqual(["Aaa", "Bbb", "Ccc", "Ddd"], fieldHelper.optionTextStrings)
            fieldHelper.assertNoOptionSelected()
        }
        group("Keyboard selection with all options") {
            fieldHelper.textField.deleteText()
            XCTAssertEqual(["Aaa", "Bbb", "Ccc", "Ddd"], fieldHelper.optionTextStrings)
            fieldHelper.assertNoOptionSelected()
            for expectedResult in ["Aaa", "Bbb", "Ccc", "Ddd", "Aaa"] { // Note: wrap around to Aaa
                group("Down-arrow to \(expectedResult)") {
                    fieldHelper.textField.typeKey(.downArrow)
                    XCTAssertEqual(expectedResult, fieldHelper.selectedOptionText)
                }
            }
            group("Down-arrow to Ddd") {
                fieldHelper.textField.typeKey(.upArrow)
                XCTAssertEqual("Ddd", fieldHelper.selectedOptionText)
                XCTAssertTrue(fieldHelper.textField.hasFocus) // just to make sure we never lost it
            }
            group("Match non-Ddd to clear the selection") {
                group("Replace field text with \"b\"") {
                    fieldHelper.textField.deleteText(andReplaceWith: "b")
                    fieldHelper.assertNoOptionSelected()
                }
                group("Arrow-down should jump to \"Bbb\"") {
                    XCTAssertEqual(["Aaa", "Bbb", "Ccc"], fieldHelper.optionTextStrings) // sanity check
                    fieldHelper.textField.typeKey(.downArrow)
                    XCTAssertEqual("Bbb", fieldHelper.selectedOptionText)
                }
                group("Another \"b\" does not clear selection") {
                    fieldHelper.textField.typeText("b")
                    // Note: The keyboard navigation
                    XCTAssertEqual("b", fieldHelper.textField.stringValue)
                    XCTAssertEqual("Bbb", fieldHelper.selectedOptionText)
                }
            }
            group("Enter key selects the option") {
                fieldHelper.textField.typeKey(.upArrow)
                XCTAssertEqual("Aaa", fieldHelper.selectedOptionText) // Sanity check
                XCTAssertEqual("", resultField.stringValue) // Make sure none of the previous stuff set this field
                fieldHelper.textField.typeKey(.enter)
                XCTAssertEqual("Aaa", resultField.stringValue)
            }
            group("Use mouse to select another option") {
                group("Open the options pane") {
                    fieldHelper.button.click()
                    XCTAssertTrue(fieldHelper.textField.hasFocus)
                }
                group("Select \"Ccc\"") {
                    fieldHelper.optionsScroll.children(matching: .textField)["Ccc"].click()
                    fieldHelper.assertOptionsPaneHidden()
                }
                XCTAssertEqual("Ccc", resultField.stringValue)
            }
        }
    }
    
    func testArrowsWhileOptionsAreClosed() {
        use("Autocomplete")
        let optionsDefinition = testWindow.textFields["test_defineoptions"]
        let resultField = testWindow.staticTexts["test_result"]
        let fieldHelper = AutocompleteFieldHelper(element: testWindow.comboBoxes["test_autocomplete"])
        optionsDefinition.deleteText(andReplaceWith: "One,Two a,Two b,Three")
        
        group("Set up blank text field") {
            fieldHelper.textField.click()
            fieldHelper.textField.typeKey(.enter)
            
            XCTAssertTrue(fieldHelper.hasFocus)
            XCTAssertEqual("", resultField.stringValue)
            fieldHelper.assertOptionsPaneHidden()
        }
        group("Text field is blank") {
            group("Down-arrow") {
                testWindow.typeKey(.downArrow)
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("", resultField.stringValue) // unchanged; action didn't run
                XCTAssertEqual("One", fieldHelper.selectedOptionText)
                
                testWindow.typeKey(.enter)
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("One", resultField.stringValue)
                fieldHelper.assertOptionsPaneHidden()
            }
            group("Clear it out and close the options again") {
                fieldHelper.textField.typeKey(.delete)
                XCTAssertEqual("", fieldHelper.textField.stringValue)
                
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("One", resultField.stringValue) // unchanged; action didn't run
                fieldHelper.assertOptionsPaneHidden()
            }
            group("Up-arrow") {
                testWindow.typeKey(.upArrow)
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("One", resultField.stringValue) // unchanged; action didn't run
                XCTAssertEqual("Three", fieldHelper.selectedOptionText)
                
                testWindow.typeKey(.enter)
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("Three", resultField.stringValue)
                fieldHelper.assertOptionsPaneHidden()
            }
        }
        group("Text field with \"Two\"") {
            group("Set up") {
                testWindow.typeText("Two") // It will have autofilled "Two a", so let's delete the " a"
                testWindow.typeKey(.delete)
                testWindow.typeKey(.enter)
            }
            group("Down-arrow") {
                testWindow.typeKey(.downArrow)
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("Two a", fieldHelper.selectedOptionText)
                
                testWindow.typeKey(.enter)
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("Two a", resultField.stringValue)
                fieldHelper.assertOptionsPaneHidden()
            }
            group("Clear it out and close the options again") {
                testWindow.typeText("Two") // It will have autofilled "Two a", so let's delete the " a"
                testWindow.typeKey(.delete)
                testWindow.typeKey(.enter)
            }
            group("Up-arrow") {
                testWindow.typeKey(.upArrow)
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("Two b", fieldHelper.selectedOptionText)
                
                testWindow.typeKey(.enter)
                XCTAssertTrue(fieldHelper.hasFocus)
                XCTAssertEqual("Two b", resultField.stringValue)
                fieldHelper.assertOptionsPaneHidden()
            }
        }
    }
    
    /// A test of the scrolling
    func testAutocompleteManyOptions() {
        use("Autocomplete")
        let optionsDefinition = testWindow.textFields["test_defineoptions"]
        let fieldHelper = AutocompleteFieldHelper(element: testWindow.comboBoxes["test_autocomplete"])

        group("Set up options") {
            optionsDefinition.deleteText(andReplaceWith: (0..<50).map({ "option \($0)"}).joined(separator: ","))
            optionsDefinition.typeKey(.enter)
        }
        group("Check the options") {
            fieldHelper.button.click()
            XCTAssertEqual(50, fieldHelper.optionTextFieldsQuery.count)
            // On my computer, it only shows 8. But maybe with other fonts, it'd be more? Let's pad it; what I'm
            // really looking for is just that *some* options are "hidden" within the scroll view
            XCTAssertTrue(fieldHelper.optionTextFieldsQuery.hasAtLeastOneElement(where: {!$0.isHittable}))
        }
        group("Arrow-up to get to the last element") {
            XCTAssertTrue(fieldHelper.textField.hasFocus) // Sanity check
            fieldHelper.textField.typeKey(.upArrow)
            XCTAssertEqual("option 49", fieldHelper.selectedOptionText)
            XCTAssertTrue(fieldHelper.optionTextField(atIndex: 49).isHittable)
        }
        group("Down-up back up to the first element") {
            XCTAssertTrue(fieldHelper.textField.hasFocus) // Sanity check
            fieldHelper.textField.typeKey(.downArrow)
            XCTAssertEqual("option 0", fieldHelper.selectedOptionText)
            XCTAssertTrue(fieldHelper.optionTextField(atIndex: 0).isHittable)
        }
    }
    
    /// Note: The XCUIElement API doesn't let us get at text selection info. We'll do our best without it.
    func testAutocompletePrefixFilling() {
        use("Autocomplete")
        let optionsDefinition = testWindow.textFields["test_defineoptions"]
        let fieldHelper = AutocompleteFieldHelper(element: testWindow.comboBoxes["test_autocomplete"])
        
        group("Set up options") {
            optionsDefinition.deleteText(andReplaceWith: "Two,Twofold test")
            fieldHelper.textField.click()
        }
        group("Type non-prefix text") {
            fieldHelper.textField.typeText("six")
            XCTAssertEqual("six", fieldHelper.textField.stringValue, "no autofill")
        }
        group("Type prefix text") {
            fieldHelper.textField.deleteText(andReplaceWith: "Tw")
            XCTAssertEqual("Two", fieldHelper.textField.stringValue, "autofill the shorter of [Two, Twofold test]")
            fieldHelper.textField.typeText("t")
            XCTAssertEqual("Twt", fieldHelper.textField.stringValue, "autofill has run out of options")
        }
        group("Autofill is case-sensitive") {
            fieldHelper.textField.deleteText(andReplaceWith: "t")
            XCTAssertEqual("t", fieldHelper.textField.stringValue) // "Two" does *not* match
        }
        group("Cancel and resume autofill") {
            group("Start autofilling") {
                fieldHelper.textField.deleteText(andReplaceWith: "Twof")
                XCTAssertEqual("Twofold test", fieldHelper.textField.stringValue)
            }
            group("Cancel the autofill") {
                fieldHelper.textField.typeKey(.delete)
                XCTAssertEqual("Twof", fieldHelper.textField.stringValue)
            }
            group("Resume it again") {
                fieldHelper.textField.typeText("o")
                XCTAssertEqual("Twofold test", fieldHelper.textField.stringValue)
            }
        }
    }
    
}
