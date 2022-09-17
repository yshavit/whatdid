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
    
    func testDateRangePane() {
        use("DateRangePane")
        
        let pickerLocations = group("calibrate picker coordinates") { () -> [(CoordinateInfo, YearMonthDay)] in
            testWindow.checkBoxes["show_calendar_calibration"].click()
            let pickerLocations = findDatePickerBoxes(in: testWindow.datePickers["calendar_calibration"])
            testWindow.checkBoxes["show_calendar_calibration"].click()
            return pickerLocations
        }
        
        // First, some simple stuff with the endpoint-selectors disclosure closed
        let rangePicker = testWindow.datePickers["range_picker"]
        let startPicker = testWindow.datePickers["start_date_picker"]
        let endPicker = testWindow.datePickers["end_date_picker"]
        let applyButton = testWindow.buttons["apply_range_button"]
        group("with endpoint selectors closed") {
            group("single date in range picker") {
                let (coordinate, ymd) = pickerLocations[0]
                coordinate.click(in: rangePicker)
                checkReportedDateRange(from: ymd, to: ymd, diff: "0m")
            }
            group("two dates in range picker") {
                let (coordinate1, ymd1) = pickerLocations[0]
                let (coordinate2, _) = pickerLocations[1]
                coordinate1.click(in: rangePicker, thenDragTo: coordinate2)
                checkReportedDateRange(from: ymd1, to: ymd1.withAdditional(days: 1), diff: "1d 0h 0m")
            }
        }
        group("open endpoint pickers") {
            group("endpoint pickers not initially visible") {
                XCTAssertFalse(startPicker.isVisible)
                XCTAssertFalse(endPicker.isVisible)
            }
            group("show endpoint pickers") {
                testWindow.disclosureTriangles["toggle_endpoint_pickers"].click()
                wait(for: "date pickers", until: { startPicker.isVisible })
                XCTAssertTrue(endPicker.isVisible)
            }
        }
        group("with endpoint selectors open") {
            group("select middle date in range picker") {
                let origReported = getReportedDateRange()
                let (coordinate, ymd) = pickerLocations[1]
                
                // Click in the range picker. The reported values shouldn't have changed yet, but the endpoint pickers should
                coordinate.click(in: rangePicker)
                checkReportedDateRange(from: origReported.from, to: origReported.to, diff: origReported.diff)
                XCTAssertEqual(ymd.asDate, startPicker.datePickerValue)
                XCTAssertEqual(ymd.asDate, endPicker.datePickerValue)
                
                // Click the apply button. Confirm the new values, and that they're different from the old
                // (being different from the old doesn't check the prod code, really; it's a validation on the test itself, to
                // protect against an accidental no-op check.)
                applyButton.click()
                let newReported = checkReportedDateRange(from: ymd, to: ymd, diff: "0m")
                XCTAssertNotEqual(origReported, newReported)
                // Endpoint pickers should be unchanged
                XCTAssertEqual(ymd.asDate, startPicker.datePickerValue)
                XCTAssertEqual(ymd.asDate, endPicker.datePickerValue)
            }
            
            group("set endpoints individually") {
                let rangeScreenshot = group("get screenshot from range") { () -> Data in
                    let (coordinate1, _) = pickerLocations[0]
                    let (coordinate2, _) = pickerLocations[2]
                    coordinate1.click(in: rangePicker, thenDragTo: coordinate2)
                    return rangePicker.getImage(andAddTo: self, withName: "target image")
                }
                let (middleDayCoordinate, middleDayYmd) = pickerLocations[1]
                group("pick middle day") {
                    middleDayCoordinate.click(in: rangePicker)
                    XCTAssertNotEqual(rangeScreenshot, rangePicker.getImage(andAddTo: self))
                }
                group("set endpoints") {
                    startPicker.typeIntoDatePicker(day: middleDayYmd.day - 1)
                    endPicker.typeIntoDatePicker(day: middleDayYmd.day + 1)
                }
                group("check ranges before clicking okay") {
                    XCTAssertEqual(rangeScreenshot, rangePicker.getImage(andAddTo: self))
                    checkReportedDateRange(from: middleDayYmd, to: middleDayYmd, diff: "0m")
                }
                group("check ranges after clicking okay") {
                    applyButton.click()
                    XCTAssertEqual(rangeScreenshot, rangePicker.getImage(andAddTo: self))
                    checkReportedDateRange(
                        from: middleDayYmd.withAdditional(days: -1),
                        to: middleDayYmd.withAdditional(days: 1),
                        diff: "2d 0h 0m")
                }
            }
            
            group("endpoints invert range") {
                // start after end, or end before start
                let (coordinate1, ymd1) = pickerLocations[0]
                let (coordinate2, ymd2) = pickerLocations[1]
                let (coordinate3, ymd3) = pickerLocations[2]
                
                group("set end before start") {
                    // If we set the end before the range's start, then start == end
                    group("select days 2-3") {
                        coordinate2.click(in: rangePicker, thenDragTo: coordinate3)
                        XCTAssertEqual(ymd2.asDate, startPicker.datePickerValue)
                        XCTAssertEqual(ymd3.asDate, endPicker.datePickerValue)
                    }
                    group("pick end as day 1") {
                        endPicker.typeIntoDatePicker(day: ymd1.day)
                        XCTAssertEqual(ymd1.asDate, startPicker.datePickerValue)
                        XCTAssertEqual(ymd1.asDate, endPicker.datePickerValue)
                    }
                }
                group("set start after end") {
                    // If we set the start after the range's end, then start == end
                    group("select days 1-2") {
                        coordinate1.click(in: rangePicker, thenDragTo: coordinate2)
                        XCTAssertEqual(ymd1.asDate, startPicker.datePickerValue)
                        XCTAssertEqual(ymd2.asDate, endPicker.datePickerValue)
                    }
                    group("pick start as day 3") {
                        startPicker.typeIntoDatePicker(day: ymd3.day)
                        XCTAssertEqual(ymd3.asDate, startPicker.datePickerValue)
                        XCTAssertEqual(ymd3.asDate, endPicker.datePickerValue)
                    }
                }
            }
        }
    }
    
    /// Checks the DateRangerPicker, which is a popdown menu button for "today/yesterday/custom."
    ///
    /// The custom view uses DateRangePane, which we test above. To simplify this test:
    ///    1. We'll assume that this uses a DateRangePane (the accessibility IDs we use will implicitly verify that)
    ///    2. We'll only set the DateRangePane's options via its individual endpoint pickers (not the range selector)
    ///
    /// While the DateRangePane's start and end are literally what the user picks (ie, they can be the same for a single-day range), the DateRangePicker
    /// always represents a Date range for which we should pick data. This means that its endpoint is actually the visible endpoint plus 1 day. For example,
    /// if you selected a single day of 2021-01-09, then the range is from 2021-01-09T09:00:00 to 2021-01-10T09:00:00.
    ///
    /// This test assumes "today" starts at 1969-12-31T09:00:00+02:00.
    func testDateRangePicker() {
        use("DateRangePicker")
        
        let pickerButton = testWindow.popUpButtons["picker"]
        group("initial state") {
            checkReportedDateRange(from: "1969-12-31T09:00:00+02:00", to: "1970-01-01T09:00:00+02:00", diff: "1d 0h 0m")
            XCTAssertEqual("today", pickerButton.stringValue)
        }
        
        func pickCustomRange(fromDay: Int, toDay: Int) {
            if pickerButton.menuItems.count == 0 {
                pickerButton.click()
            }
            XCTAssertEqual(
                ["today", "yesterday", "custom"],
                pickerButton.menuItems.allElementsBoundByIndex.map({$0.title}))
            let datePicker = pickerButton.datePickers.firstMatch
            pickerButton.menuItems["custom"].click()
            wait(for: "date picker to show", until: { datePicker.isVisible })
            pickerButton.disclosureTriangles["toggle_endpoint_pickers"].click()
            
            testWindow.datePickers["start_date_picker"].typeIntoDatePicker(day: fromDay)
            testWindow.datePickers["end_date_picker"].typeIntoDatePicker(day: toDay)
            testWindow.buttons["apply_range_button"].click()
            
            wait(for: "date picker to hide", until: { !datePicker.isVisible })
        }
        
        group("pick yesterday") {
            pickerButton.click()
            pickerButton.menuItems["yesterday"].click()
            checkReportedDateRange(
                from: "1969-12-30T09:00:00+02:00",
                to: "1969-12-31T09:00:00+02:00",
                diff: "1d 0h 0m")
            XCTAssertEqual("yesterday", pickerButton.stringValue)
        }
        group("clicking away from custom keeps selection on 'yesterday'") {
            func menuItemsWithSelection() -> [String] {
                return pickerButton.menuItems.allElementsBoundByIndex.map {item in
                    var title = ""
                    if item.isSelected {
                        title += "* "
                    }
                    title += item.title
                    return title
                }
            }
            // Initiate expected state (from previous group)
            XCTAssertEqual("yesterday", pickerButton.stringValue)
            
            // Click the button and open the custom range view
            pickerButton.click()
            XCTAssertEqual(["today", "* yesterday", "custom"], menuItemsWithSelection())
            pickerButton.menuItems["custom"].click()
            wait(for: "date picker to open", until: { pickerButton.datePickers.count > 0 })
            XCTAssertEqual("custom", pickerButton.stringValue)
            
            // Click away to close the popover
            testWindow.staticTexts["result_start"].click(using: .frame(xInlay: 0.01))
            wait(for: "date picker to close", until: { pickerButton.datePickers.count == 0 })
            sleepMillis(500) // give it a chance to stabilize
            XCTAssertEqual("yesterday", pickerButton.stringValue)
            
            // Now click on the button again. The "yesterday" option should still be selected.
            pickerButton.click()
            XCTAssertEqual(["today", "* yesterday", "custom"], menuItemsWithSelection())
            testWindow.staticTexts["result_start"].click(using: .frame(xInlay: 0.01))
            wait(for: "menu options to close", until: { pickerButton.menuItems.count == 0 })
        }
        group("pick today") {
            pickerButton.click()
            pickerButton.menuItems["today"].click()
            checkReportedDateRange(
                from: "1969-12-31T09:00:00+02:00",
                to: "1970-01-01T09:00:00+02:00",
                diff: "1d 0h 0m")
            XCTAssertEqual("today", pickerButton.stringValue)
        }
        group("pick yesterday as custom") {
            pickCustomRange(fromDay: 30, toDay: 30)
            checkReportedDateRange(
                from: "1969-12-30T09:00:00+02:00",
                to: "1969-12-31T09:00:00+02:00",
                diff: "1d 0h 0m")
            XCTAssertEqual("yesterday", pickerButton.stringValue)
        }
        group("pick today as custom") {
            pickCustomRange(fromDay: 31, toDay: 31)
            checkReportedDateRange(
                from: "1969-12-31T09:00:00+02:00",
                to: "1970-01-01T09:00:00+02:00",
                diff: "1d 0h 0m")
            XCTAssertEqual("today", pickerButton.stringValue)
        }
        group("one custom day") {
            pickCustomRange(fromDay: 13, toDay: 13)
            checkReportedDateRange(
                from: "1969-12-13T09:00:00+02:00",
                to: "1969-12-14T09:00:00+02:00",
                diff: "1d 0h 0m")
            XCTAssertEqual("Dec 13", pickerButton.stringValue)
        }
        group("two custom days") {
            pickCustomRange(fromDay: 13, toDay: 14)
            checkReportedDateRange(
                from: "1969-12-13T09:00:00+02:00",
                to: "1969-12-15T09:00:00+02:00",
                diff: "2d 0h 0m")
            XCTAssertEqual("Dec 13 and Dec 14", pickerButton.stringValue)
        }
        group("three custom days") {
            pickCustomRange(fromDay: 13, toDay: 15)
            checkReportedDateRange(
                from: "1969-12-13T09:00:00+02:00",
                to: "1969-12-16T09:00:00+02:00",
                diff: "3d 0h 0m")
            XCTAssertEqual("Dec 13 through Dec 15", pickerButton.stringValue)
        }
        group("popover keeps current custom selection") {
            pickerButton.click()
            XCTAssertEqual(
                ["today", "yesterday", "custom"],
                pickerButton.menuItems.allElementsBoundByIndex.map({$0.title}))
            let datePicker = pickerButton.datePickers.firstMatch
            pickerButton.menuItems["custom"].click()
            wait(for: "date picker to show", until: { datePicker.isVisible })
            pickerButton.disclosureTriangles["toggle_endpoint_pickers"].click()
            
            XCTAssertEqual("1969-12-13 07:00:00 +0000", testWindow.datePickers["start_date_picker"].datePickerValue.description)
            XCTAssertEqual("1969-12-15 07:00:00 +0000", testWindow.datePickers["end_date_picker"].datePickerValue.description)
        }
        group("range ending yesterday") {
            pickCustomRange(fromDay: 13, toDay: 30)
            checkReportedDateRange(
                from: "1969-12-13T09:00:00+02:00",
                to: "1969-12-31T09:00:00+02:00",
                diff: "18d 0h 0m")
            XCTAssertEqual("Dec 13 through yesterday", pickerButton.stringValue)
        }
        group("range ending today") {
            pickCustomRange(fromDay: 13, toDay: 31)
            checkReportedDateRange(
                from: "1969-12-13T09:00:00+02:00",
                to: "1970-01-01T09:00:00+02:00",
                diff: "19d 0h 0m")
            XCTAssertEqual("Dec 13 through today", pickerButton.stringValue)
        }
        group("yesterday and today") {
            pickCustomRange(fromDay: 30, toDay: 31)
            checkReportedDateRange(
                from: "1969-12-30T09:00:00+02:00",
                to: "1970-01-01T09:00:00+02:00",
                diff: "2d 0h 0m")
            XCTAssertEqual("yesterday and today", pickerButton.stringValue)
        }
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
            group("Up-arrow to Ddd") {
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
                    XCTAssertEqual("bb", fieldHelper.textField.stringValue)
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
                    fieldHelper.optionsScroll.descendants(matching: .textField)["Ccc"].click()
                    fieldHelper.assertOptionsPaneHidden()
                }
                XCTAssertEqual("Ccc", resultField.stringValue)
            }
            group("selection state rests when popup closes") {
                group("initialize") {
                    fieldHelper.textField.deleteText(andReplaceWith: "b")
                }
                for i in 1...2 {
                    group("arrow down #\(i)") {
                        XCTAssertFalse(fieldHelper.optionsScrollIsOpen)
                        fieldHelper.textField.typeKey(XCUIKeyboardKey.downArrow)
                        XCTAssertEqual("Bbb", fieldHelper.selectedOptionText)
                        fieldHelper.textField.typeKey(.escape)
                    }
                }
                group("arrow up") {
                    XCTAssertFalse(fieldHelper.optionsScrollIsOpen)
                    fieldHelper.textField.typeKey(XCUIKeyboardKey.upArrow)
                    XCTAssertEqual("Ccc", fieldHelper.selectedOptionText)
                    fieldHelper.textField.typeKey(.escape)
                }
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
    
    private struct ReportedDateRange: Equatable {
        let from: String
        let to: String
        let diff: String
    }
    
    private func getReportedDateRange() -> ReportedDateRange {
        return ReportedDateRange(
            from: testWindow.staticTexts["result_start"].stringValue,
            to: testWindow.staticTexts["result_end"].stringValue,
            diff: testWindow.staticTexts["result_diff"].stringValue
        )
    }
    
    @discardableResult
    private func checkReportedDateRange(from: String, to: String, diff: String) -> ReportedDateRange {
        let actual = getReportedDateRange()
        XCTAssertEqual(from, actual.from)
        XCTAssertEqual(to, actual.to)
        XCTAssertEqual(diff, actual.diff)
        return actual
    }
    
    @discardableResult
    private func checkReportedDateRange(from: YearMonthDay, to: YearMonthDay, diff: String) -> ReportedDateRange {
        return checkReportedDateRange(
            from: "\(from.asDashedString)T09:00:00+02:00",
            to: "\(to.asDashedString)T09:00:00+02:00",
            diff: diff)
    }
}
