// whatdidUITests?

import XCTest
@testable import whatdid

class PtnViewControllerTest: AppUITestBase {
    
    func testRequiredFields() {
        let ptn = openPtn()
        
        /// Click to the project field, and then tab to the other two.
        /// Because focusing one of these fields also selects all its text, we can delete by just pressing the delete key.
        /// This always hits the enter key on notes.
        func typeViaTabs(_ p: String, _ t: String, _ n: String) {
            ptn.pcombo.textField.click()
            for entry in [p + "\t", t + "\t", n + "\r"] {
                if entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    app.typeKey(.delete)
                }
                app.typeText(entry)
            }
        }
        
        group("project is required") {
            typeViaTabs("", "task", "notes")
            sleep(1)
            XCTAssertEqual(.ptn, openWindowType)
        }
        group("task is required") {
            typeViaTabs("project", "", "notes")
            sleep(1)
            XCTAssertEqual(.ptn, openWindowType)
        }
        group("notes are not required") {
            typeViaTabs("project", "task", "")
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("set preferences to require notes") {
            group("open PTN back up") {
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: true)
                XCTAssertEqual("notes", ptn.nfield.placeholderValue) // not "(required)"
            }
            let prefsSheet = group("open prefs") {() -> XCUIElement in
                ptn.window.buttons["Preferences"].click()
                let prefsSheet = ptn.window.sheets.firstMatch
                wait(for: "prefs sheet to show", until: {prefsSheet.isVisible})
                return prefsSheet
            }
            group("set prefs and hide window") {
                prefsSheet.tabs["General"].click()
                prefsSheet.checkBoxes["Require Notes"].click()
                prefsSheet.buttons["Done"].click()
                wait(for: "prefs sheet to hide", until: {!prefsSheet.isVisible})
            }
        }
        group("verify notes are required") {
            XCTAssertEqual("notes (required)", ptn.nfield.placeholderValue)
            typeViaTabs("project", "task", "")
            sleep(1)
            XCTAssertEqual(.ptn, openWindowType)
        }
    }
    
    func testResizing() {
        let ptn = openPtn()
        func checkVerticalAlignments() {
            group("Check vertical alignments") {
                let pY = ptn.pcombo.textField.frame.minY
                let yY = ptn.tcombo.textField.frame.minY
                let nY = ptn.nfield.frame.minY
                XCTAssertEqual(pY, yY)
                XCTAssertEqual(yY, nY)
                XCTAssertEqual(pY, ptn.window.staticTexts["/"].frame.minY)
                XCTAssertEqual(pY, ptn.window.staticTexts[":"].frame.minY)
            }
        }
        func typeUntilWrapping(field: XCUIElement, lines: Int) -> CGFloat {
            let words = String(repeating: "the quick brown fox jumped over the lazy dog ", count: 5).split(separator: " ")
            field.click()
            var wrapsRemaining = lines - 1 // for instance, if we need two lines, we need to wrap once
            var oldHeight = field.frame.height
            for word in words {
                field.typeText("\(word) ")
                let newHeight = field.frame.height
                XCTAssertGreaterThanOrEqual(newHeight, oldHeight)
                if newHeight > oldHeight {
                    wrapsRemaining -= 1
                    if wrapsRemaining == 0 {
                        return newHeight
                    } else {
                        oldHeight = newHeight
                    }
                }
            }
            XCTFail("ran out of words before reaching expected wrap")
            return -1 // won't ever happen
        }
        
        let (originalHeightT, originalHeightN) = group("Get baseline") {() -> (CGFloat, CGFloat) in
            checkVerticalAlignments()
            return (ptn.tcombo.textField.frame.height, ptn.nfield.frame.height)
        }
        
        ///  For each of {P, T, N}:
        /// 1. Type some text until it wraps (to a different number of lines for each one)
        /// 2. Check that everything is still aligned to top
        /// 3. Check that the other two fields haven't changed heights
        let newHeightP = group("type wrapping text into project") {() -> CGFloat in
            let pHeight = typeUntilWrapping(field: ptn.pcombo.textField, lines: 4)
            checkVerticalAlignments()
            XCTAssertEqual(originalHeightT, ptn.tcombo.textField.frame.height)
            XCTAssertEqual(originalHeightN, ptn.nfield.frame.height)
            return pHeight
        }
        let newHeightT = group("type wrapping text into task") {() -> CGFloat in
            let tHeight = typeUntilWrapping(field: ptn.tcombo.textField, lines: 3)
            checkVerticalAlignments()
            XCTAssertEqual(newHeightP, ptn.pcombo.textField.frame.height)
            XCTAssertEqual(originalHeightN, ptn.nfield.frame.height)
            return tHeight
        }
        group("type wrapping text into notes") {
            let _ = typeUntilWrapping(field: ptn.nfield, lines: 2)
            checkVerticalAlignments()
            XCTAssertEqual(newHeightP, ptn.pcombo.textField.frame.height)
            XCTAssertEqual(newHeightT, ptn.tcombo.textField.frame.height)
        }
    }
    
    func testResizingAndAutoComplete() {
        let ptn = openPtn()
        group("initalize the data") {
            // Three entries, in shuffled alphabetical order (neither fully ascending or descending)
            // We want both the lowest and highest values (alphanumerically) to be in the middle.
            // That means that when we autocomplete "wh*", we can be sure that we're getting date-ordered
            // entries.
            entriesHook = [
                entry("wheredid", "something else", "notes 2", from: t(-100), to: t(-90)),
                entry("whatdid", "autothing", "notes 1", from: t(-80), to: t(-70)),
                entry("whytdid", "autothing", "notes 1", from: t(-80), to: t(-70)),
                entry("whodid", "something else", "notes 2", from: t(-60), to: t(-50))]
        }
        group("autocomplete wh*") {
            let pcombo = ptn.pcombo.textField
            pcombo.click()
            pcombo.typeKey(.downArrow)
            pcombo.typeText("\r")
            XCTAssertEqual("whodid", pcombo.stringValue)
        }
    }

    func testFocus() {
        let ptn = openPtn()
        group("Set up hot key") {
            let prefsButton = ptn.window.buttons["Preferences"]
            let prefsSheet = ptn.window.sheets.firstMatch
            prefsButton.click()
            XCTAssertTrue(prefsSheet.isVisible)
            prefsSheet.tabs["General"].click()
            prefsSheet.searchFields["Record Shortcut"].click()
            ptn.window.typeKey("x", modifierFlags:[.command, .shift])
            prefsSheet.buttons["Done"].click()
        }
        group("Scheduled PTN does not activate") {
            setTimeUtc(h: 01, m: 00, deactivate: true)
            sleep(1) // If it was going to be switch to active, this would be enough time
            XCTAssertTrue(ptn.window.isVisible)
            XCTAssertEqual(XCUIApplication.State.runningBackground, app.state)
        }
        group("Hot key grabs focus with PTN open") {
            // Assume from previous that window is visible but app is in background
            pressHotkeyShortcut()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
            group("Type text to sanity check focus") {
                ptn.pcombo.textField.typeText("hello 1")
                XCTAssertEqual("hello 1", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.deleteText()
            }
        }
        group("Closing the menu resigns active") {
            clickStatusMenu() // close the app
            wait(for: "window to close", until: {openWindow == nil})
            XCTAssertTrue(app.wait(for: .runningBackground, timeout: 30))
        }
        group("Hot key opens PTN with active and focus") {
            pressHotkeyShortcut()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
            group("Type text to check focus") {
                ptn.pcombo.textField.typeText("hello 2")
                XCTAssertEqual("hello 2", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.deleteText()
            }
        }
        group("Opening the menu activates") {
            group("Close PTN") {
                clickStatusMenu() // close the app
                waitForTransition(of: .ptn, toIsVisible: false)
                XCTAssertTrue(app.wait(for: .runningBackground, timeout: 30))
            }
            clickStatusMenu() // But do *not* do anything more than that to grab focus!
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
            group("Type text to check focus") {
                ptn.pcombo.textField.typeText("hello 3")
                XCTAssertEqual("hello 3", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.deleteText()
            }
        }
        group("Clicking selects all") {
            group("Setup") {
                ptn.pcombo.textField.click()
                ptn.window.typeText("Project 1\tTask 1\tNotes 1")
            }
            group("Click in Task field") {
                XCTAssertEqual("Task 1", ptn.tcombo.textField.stringValue)
                ptn.tcombo.textField.click()
                ptn.window.typeText("Task Two")
                XCTAssertEqual("Task Two", ptn.tcombo.textField.stringValue)
            }
            group("Click in Project field") {
                XCTAssertEqual("Project 1", ptn.pcombo.textField.stringValue)
                ptn.pcombo.textField.click()
                ptn.window.typeText("Project Two")
                XCTAssertEqual("Project Two", ptn.pcombo.textField.stringValue)
            }
            group("Click in Notes field") {
                XCTAssertEqual("Notes 1", ptn.nfield.stringValue)
                ptn.nfield.click()
                ptn.window.typeText("Notes Two")
                XCTAssertEqual("Notes Two", ptn.nfield.stringValue)
            }
        }
    }

    func testKeyboardNavigation() {
        let ptn = openPtn()
        group("forward tabbing") {
            XCTAssertTrue(ptn.pcombo.hasFocus) // Sanity check
            // Tab from Project -> Task
            ptn.window.typeKey(.tab)
            XCTAssertTrue(ptn.tcombo.hasFocus)
            // Tab from Task -> Notes
            ptn.window.typeKey(.tab)
            XCTAssertTrue(ptn.window.textFields["nfield"].hasFocus)
        }
        group("backward tabbing") {
            XCTAssertTrue(ptn.window.textFields["nfield"].hasFocus) // Sanity check
            // Backtab from Notes to Task
            ptn.window.typeKey(.tab, modifierFlags: .shift)
            XCTAssertTrue(ptn.tcombo.hasFocus)
            // Backtab from Task to Project
            ptn.window.typeKey(.tab, modifierFlags: .shift)
            XCTAssertTrue(ptn.pcombo.hasFocus)
        }
        group("enter key") {
            XCTAssertTrue(ptn.pcombo.hasFocus) // Sanity check
            // Enter from Project to Task
            ptn.pcombo.textField.typeKey(.enter)
            XCTAssertTrue(ptn.tcombo.hasFocus)
            // Enter from Task to Notes
            ptn.pcombo.textField.typeKey(.enter)
            XCTAssertTrue(ptn.window.textFields["nfield"].hasFocus)
        }
        group("escape key within notes") {
            XCTAssertTrue(ptn.window.textFields["nfield"].hasFocus)
            ptn.window.typeKey(.escape, modifierFlags: [])
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("escape key within project combo") {
            group("Open PTN") {
                wait(for: "window to close", until: {openWindow == nil})
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: true)
            }
            group("Escape key #1: hide options") {
                XCTAssertTrue(ptn.pcombo.textField.hasFocus)
                XCTAssertTrue(ptn.pcombo.optionsScroll.isVisible)
                ptn.window.typeKey(.escape, modifierFlags: [])
                XCTAssertFalse(ptn.pcombo.optionsScrollIsOpen)
            }
            group("Escape key #2: hide window") {
                waitForTransition(of: .ptn, toIsVisible: true)
                ptn.window.typeKey(.escape, modifierFlags: [])
                waitForTransition(of: .ptn, toIsVisible: false)
            }
        }
    }
    
    func testFieldClearingOnPopup() {
        let ptn = openPtn()
        group("Type project, then abandon") {
            XCTAssertTrue(ptn.pcombo.hasFocus)
            app.typeText("project a\r")
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Type task, then abandon") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertTrue(ptn.tcombo.hasFocus)
            app.typeText("task b\r")
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Enter notes") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertTrue(ptn.nfield.hasFocus)
            app.typeText("notes c\r")
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Reopen PTN") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertTrue(ptn.nfield.hasFocus)
            XCTAssertEqual("", ptn.nfield.stringValue)
        }
        group("Change project") {
            ptn.pcombo.textField.deleteText()
            XCTAssertEqual("", ptn.pcombo.textField.stringValue) // sanity check
            XCTAssertEqual("", ptn.tcombo.textField.stringValue) // changing pcombo should change tcombo
        }
    }
    
    func testSkipSessionButton() {
        group("Clear out previous entries") {
            setTimeUtc(h: 1, m: 00)
            waitForTransition(of: .ptn, toIsVisible: true)
        }
        group("Skip a session") {
            find(.ptn).buttons["Skip session"].click()
            waitForTransition(of: .ptn, toIsVisible: false)
        }
        group("Make an entry") {
            setTimeUtc(h: 1, m: 15)
            findPtn().pcombo.textField.deleteText(andReplaceWith: "One\tTwo\tThree\r")
        }
        group("Validate") {
            clickStatusMenu()
            waitForTransition(of: .ptn, toIsVisible: true)
            XCTAssertEqual(
                [FlatEntry(from: date(h: 1, m: 00), to: date(h: 1, m: 15), project: "One", task: "Two", notes: "Three")],
                entriesHook)
        }
    }
}
