// whatdidUITests?

import XCTest
@testable import Whatdid

class TutorialTest: AppUITestBase {
    
    func testTutorial() {
        let tutorialPopover = group("restart app with tutorial") {() -> XCUIElement in
            launch(withEnv: startupEnv(suppressTutorial: false))
            return app.windows[WindowType.ptn.windowTitle].popovers.element
        }
        let tutorialWelcomeText = "This window will pop up every so often to ask you what you've been up to."
        let tutorialProjectText = "Enter the project you've been working on."
        
        group("Spot check tutorial text") {
            XCTAssertEqual(
                1,
                tutorialPopover.staticTexts.allElementsBoundByIndex.filter({$0.stringValue.contains(tutorialWelcomeText)}).count
            )
        }
        group("Set launch-on-login") {
            // Set launch-on-login
            let launchOnLogin = tutorialPopover.checkBoxes.element
            XCTAssertEqual(false, launchOnLogin.value as? Bool)
            launchOnLogin.click()
            // not super interesting so far, but we'll also check the pref later
            XCTAssertEqual(true, launchOnLogin.value as? Bool)
        }
        group("Set global shortcut") {
            let recordShortcutSearchField = tutorialPopover.searchFields["Record Shortcut"]
            
            recordShortcutSearchField.click()
            recordShortcutSearchField.typeKey("u", modifierFlags:[.command, .shift])
            XCTAssertEqual(recordShortcutSearchField.stringValue, "⇧⌘U")
        }
        group("Next tutorial pane") {
            tutorialPopover.buttons[">"].click()
            XCTAssertEqual(
                1,
                tutorialPopover.staticTexts.allElementsBoundByIndex.filter({$0.stringValue.contains(tutorialProjectText)}).count
            )
        }
        group("Previous tutorial pane") {
            tutorialPopover.buttons["<"].click()
            XCTAssertEqual(
                1,
                tutorialPopover.staticTexts.allElementsBoundByIndex.filter({$0.stringValue.contains(tutorialWelcomeText)}).count
            )
        }
        group("Close the tutorial") {
            tutorialPopover.buttons["Done"].click()
            wait(for: "tutorial to close", until: {app.windows[WindowType.ptn.windowTitle].popovers.count == 0})
        }
        group("Tutorial doesn't open at next PTN open") {
            group("close PTN") {
                clickStatusMenu()
                waitForTransition(of: .ptn, toIsVisible: false)
                XCTAssertEqual(0, app.windows[WindowType.ptn.windowTitle].popovers.count)
            }
            group("reopen PTN using configured shortcut") {
                pressHotkeyShortcut(keyCode: 0x20) // 0x20 is "u"
                waitForTransition(of: .ptn, toIsVisible: true)
                XCTAssertEqual(0, app.windows[WindowType.ptn.windowTitle].popovers.count)
            }
        }
        group("check preferences") {
            let ptnWindow = app.windows[WindowType.ptn.windowTitle]
            ptnWindow.buttons["Preferences"].click()
            let prefsSheet = ptnWindow.sheets.firstMatch
            XCTAssertTrue(prefsSheet.isVisible)
            group("General tab") {
                prefsSheet.tabs["General"].click()
                XCTAssertEqual(true, prefsSheet.checkBoxes["Launch at Login"].value as? Bool)
                prefsSheet.checkBoxes["Launch at Login"].click() // turn off launch-at-login
                XCTAssertEqual("⇧⌘U", prefsSheet.searchFields["Record Shortcut"].stringValue)
            }
            group("Show tutorial again") {
                prefsSheet.tabs["Help & Feedback"].click()
                prefsSheet.buttons["Show tutorial again"].click()
                wait(for: "preferences sheet to close", until: {ptnWindow.exists && ptnWindow.sheets.count == 0})
                wait(for: "tutorial to open", until: {app.windows[WindowType.ptn.windowTitle].popovers.count == 1})
                XCTAssertEqual(
                    1,
                    tutorialPopover.staticTexts.allElementsBoundByIndex.filter({$0.stringValue.contains(tutorialWelcomeText)}).count
                )
                // The "launch at login" and "record shortcut" controls should *not* be there this time
                XCTAssertEqual(0, tutorialPopover.checkBoxes.count)
                XCTAssertFalse(prefsSheet.searchFields["Record Shortcut"].exists)
            }
        }
    }
}
