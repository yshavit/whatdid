// whatdid?

import XCTest
@testable import whatdid

class ComponentUITests: XCTestCase {

    private var app: XCUIApplication!
    
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment = startupEnv(suppressTutorial: true)
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
    
    func testGoalsView() {
        use("GoalsView")
        
        func findGoalsBar(_ idx: Int) -> XCUIElement {
            let e = testWindow.children(matching: .group).matching(identifier: "Goals for today").element(boundBy: idx)
            XCTAssertTrue(e.exists)
            return e
        }
        
        group("short task") {
            let goalsBar = findGoalsBar(0)
            let textField = goalsBar.children(matching: .textField).element
            XCTAssertFalse(textField.exists)
            
            goalsBar.buttons["Add new goal"].click()
            XCTAssertTrue(textField.isVisible)
            XCTAssertEqual("", textField.stringValue)
            
            XCTAssertTrue(textField.hasFocus)
            textField.typeText("one\r")
            XCTAssertFalse(textField.exists)
            
            XCTAssertEqual(["one"], goalsBar.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([], findGoalsBar(1).checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
        group("long task") {
            let goalsBar = findGoalsBar(0)
            let textField = goalsBar.children(matching: .textField).element
            goalsBar.buttons["Add new goal"].click()
            let initialWidth = textField.frame.width
            group("starts expanding") {
                for _ in 0..<100 {
                    textField.typeText("x")
                    if textField.frame.width != initialWidth {
                        break
                    }
                }
                XCTAssertGreaterThan(textField.frame.width, initialWidth)
            }
            group("shrinks again") {
                // The "starts expanding" group made us be one bigger than min, so let's delete two chars to check the collapse
                textField.typeKey(.delete)
                XCTAssertEqual(textField.frame.width, initialWidth)
                textField.typeKey(.delete)
                XCTAssertEqual(textField.frame.width, initialWidth)
            }
            let frameBeforeWrap = textField.frame
            group("wraps to next line") {
                for _ in 0..<100 {
                    textField.typeText(" word")
                    if textField.frame.minY != frameBeforeWrap.minY {
                        break
                    }
                }
                let afterWrap = textField.frame
                XCTAssertGreaterThan(afterWrap.minY, frameBeforeWrap.minY)
                XCTAssertEqual(afterWrap.height, frameBeforeWrap.height)
                XCTAssertClose(
                    goalsBar.staticTexts.element(boundBy: 0).frame.minX,
                    afterWrap.minX,
                    within: 5) // it's okay if they're unaligned by a few pixels
            }
            group("unwraps back to original line") {
                textField.typeKey(.delete, modifierFlags: .option)
                textField.typeKey(.delete)
                let afterUnwrap = textField.frame
                XCTAssertEqual(afterUnwrap.minY, frameBeforeWrap.minY)
                XCTAssertClose(
                    frameBeforeWrap.minX,
                    afterUnwrap.minX,
                    within: 0) // it's okay if they're unaligned by a few pixels
            }
        }
        group("enter blank goal") {
            let goalsBar = findGoalsBar(0)
            let textField = goalsBar.children(matching: .textField).element
            textField.typeKey("a", modifierFlags: .command)
            textField.typeText("  \r")

            // field is dismissed, but no new goals
            XCTAssertFalse(textField.exists)
            XCTAssertEqual(["one"], goalsBar.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
        group("enter a second goal") {
            let goalsBar = findGoalsBar(0)
            let textField = goalsBar.children(matching: .textField).element
            goalsBar.buttons["Add new goal"].click()
            textField.typeText("two")
            goalsBar.buttons["Add new goal"].click() // don't submit via enter; submit via the button
            
            XCTAssertFalse(textField.exists)
            XCTAssertEqual(["one", "two"], goalsBar.checkBoxes.allElementsBoundByIndex.map({$0.title}))
        }
        group("both boxes are unselected") {
            XCTAssertEqual([false, false], findGoalsBar(0).checkBoxes.allElementsBoundByIndex.map({$0.boolValue}))
        }
        group("select second goal") {
            let goalsBar = findGoalsBar(0)
            goalsBar.checkBoxes["two"].click()
            XCTAssertEqual([false, true], goalsBar.checkBoxes.allElementsBoundByIndex.map({$0.boolValue}))
        }
        group("sync to second goals bar") {
            let secondBar = findGoalsBar(1)
            
            XCTAssertEqual([], secondBar.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([], secondBar.checkBoxes.allElementsBoundByIndex.map({$0.boolValue}))
            testWindow.buttons["sync goals"].click()
            XCTAssertEqual(["one", "two"], secondBar.checkBoxes.allElementsBoundByIndex.map({$0.title}))
            XCTAssertEqual([false, true], secondBar.checkBoxes.allElementsBoundByIndex.map({$0.boolValue}))
            
            XCTAssertFalse(secondBar.children(matching: .textField).element.exists)
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
    
    func testDateRangePicker() {
        use("DateRangePicker")
        func checkReportedRange(from: String, to: String, diff: String) {
            XCTAssertEqual(
                from,
                testWindow.staticTexts["result_start"].stringValue)
            XCTAssertEqual(
                to,
                testWindow.staticTexts["result_end"].stringValue)
            XCTAssertEqual(
                diff,
                testWindow.staticTexts["result_diff"].stringValue)
        }
        let pickerLocations = group("calibrate picker coordinates") { () -> [(CoordinateInfo, YearMonthDay)] in
            testWindow.checkBoxes["show_calendar_calibration"].click()
            let pickerLocations = findDatePickerBoxes(in: testWindow.datePickers["calendar_calibration"])
            testWindow.checkBoxes["show_calendar_calibration"].click()
            return pickerLocations
        }
        
        let pickerButton = testWindow.popUpButtons["picker"]
        group("initial state") {
            checkReportedRange(from: "1969-12-31T09:00:00+02:00", to: "1970-01-01T09:00:00+02:00", diff: "1d 0h 0m")
            XCTAssertEqual("today", pickerButton.stringValue)
        }
        group("initial selection") {
            pickerButton.click()
            XCTAssertEqual(
                ["today", "yesterday", "custom"],
                pickerButton.menuItems.allElementsBoundByIndex.map({$0.title}))
        }
        
        // Note: because of how we find the coordinate + YMDs, we assume no month-boundaries.
        // That is, the YYYY and MM are the same, and only the day increments.
        // We'll also assume everything is in December, for simplicity.
        group("pick one custom day") {
            let datePicker = pickerButton.datePickers.firstMatch
            pickerButton.menuItems["custom"].click()
            wait(for: "date picker to show", until: { datePicker.isVisible })
            let (coordinate, ymd) = pickerLocations[0]
            coordinate.click(in: datePicker)
            checkReportedRange(
                from: "\(ymd.asDashedString)T09:00:00+02:00",
                to: "\(ymd.withAdditional(days: 1).asDashedString)T09:00:00+02:00",
                diff: "1d 0h 0m")
            XCTAssertEqual("Dec \(ymd.day)", pickerButton.stringValue)
        }
        group("pick two days") {
            let datePicker = pickerButton.datePickers.firstMatch
            pickerButton.click()
            pickerButton.menuItems["custom"].click()
            wait(for: "date picker to show", until: { datePicker.isVisible })
            let (coordinate1, ymd) = pickerLocations[0]
            let (coordinate2, _) = pickerLocations[1]
            coordinate1.click(in: datePicker, thenDragTo: coordinate2)
            checkReportedRange(
                from: "\(ymd.asDashedString)T09:00:00+02:00",
                to: "\(ymd.withAdditional(days: 2).asDashedString)T09:00:00+02:00",
                diff: "2d 0h 0m")
            XCTAssertEqual("Dec \(ymd.day) and Dec \(ymd.day + 1)", pickerButton.stringValue)
        }
        group("pick three days") {
            let datePicker = pickerButton.datePickers.firstMatch
            pickerButton.click()
            pickerButton.menuItems["custom"].click()
            wait(for: "date picker to show", until: { datePicker.isVisible })
            let (coordinate1, ymd) = pickerLocations[0]
            let (coordinate2, _) = pickerLocations[2]
            coordinate1.click(in: datePicker, thenDragTo: coordinate2)
            checkReportedRange(
                from: "\(ymd.asDashedString)T09:00:00+02:00",
                to: "\(ymd.withAdditional(days: 3).asDashedString)T09:00:00+02:00",
                diff: "3d 0h 0m")
            XCTAssertEqual("Dec \(ymd.day) through Dec \(ymd.day + 2)", pickerButton.stringValue)
        }
        group("pick today") {
            let datePicker = pickerButton.datePickers.firstMatch
            pickerButton.click()
            pickerButton.menuItems["today"].click()
            sleepMillis(1500)
            XCTAssertFalse(datePicker.isVisible)
            checkReportedRange(
                from: "1969-12-31T09:00:00+02:00",
                to: "1970-01-01T09:00:00+02:00",
                diff: "1d 0h 0m")
            XCTAssertEqual("today", pickerButton.stringValue)
        }
        group("pick yesterday") {
            let datePicker = pickerButton.datePickers.firstMatch
            pickerButton.click()
            pickerButton.menuItems["yesterday"].click()
            sleepMillis(1500)
            XCTAssertFalse(datePicker.isVisible)
            checkReportedRange(
                from: "1969-12-30T09:00:00+02:00",
                to: "1969-12-31T09:00:00+02:00",
                diff: "1d 0h 0m")
            XCTAssertEqual("yesterday", pickerButton.stringValue)
        }
        // TODO:
        // 1: use the date picker to pick today and yesterday; confirm that the pickerButton.stringValue says "today".
        // 2: use the date picker to select a range including today/yesterday, and confirm the pickerButton.stringValue
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
            group("tabbing selected all") {
                testWindow.typeText("select-all 1\r")
                XCTAssertEqual("select-all 1", resultField.stringValue)
                XCTAssertTrue(fieldHelper.hasFocus) // we still have focus
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
        group("Clicking field selects-all") {
            XCTAssertFalse(fieldHelper.hasFocus) // sanity check
            fieldHelper.textField.click()
            testWindow.typeText("select-all 2\r")
            XCTAssertEqual("select-all 2", resultField.stringValue)
        }
        group("text wrapping") {
            let origHeight = group("Setup and sanity check") { () -> CGFloat in 
                fieldHelper.textField.deleteText()
                fieldHelper.button.click() // open the scroll frame
                fieldHelper.checkOptionsScrollFrameHeight()
                return fieldHelper.textField.frame.height
            }
            group("Type until wrap") {
                // Do this in a while loop so that we can adjust for font sizes.
                var words = "the quick brown fox jumped over the lazy dog".split(separator: " ")
                words.append(contentsOf: words) // 2x just to be safe
                for word in words {
                    fieldHelper.textField.typeText(" \(word)")
                    if fieldHelper.textField.frame.height != origHeight {
                        break
                    }
                }
                XCTAssertNotEqual(origHeight, fieldHelper.textField.frame.height)
                fieldHelper.checkOptionsScrollFrameHeight()
            }
            group("Delete all text") {
                fieldHelper.textField.deleteText()
                XCTAssertEqual(origHeight, fieldHelper.textField.frame.height)
                fieldHelper.checkOptionsScrollFrameHeight()
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
