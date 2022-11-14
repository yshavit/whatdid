// whatdidTests?

import XCTest
@testable import whatdid

class PtnViewControllerTest: ControllerTestBase<PtnViewController> {

    func testFocusPreservesFields() {
        let (ptn, window) = openPtn { dataBuilder in
            dataBuilder.add(project: "my_proj", task: "my_task", note: "", withDuration: 60)
        }
        // initial state
        XCTAssertIdentical(ptn.projectField, autoCompletingField(containing: window.firstResponder))
        XCTAssertTrue(ptn.projectField.popupIsOpen)
        XCTAssertEqual("", ptn.projectField.stringValue)
        XCTAssertFalse(ptn.taskField.popupIsOpen)
        XCTAssertEqual("", ptn.taskField.stringValue)

        sendEvents(simulateTyping: "hello\tworld", into: ptn.projectField)

        // after "hello⇥world":
        XCTAssertIdentical(ptn.taskField, autoCompletingField(containing: window.firstResponder))
        XCTAssertFalse(ptn.projectField.popupIsOpen)
        XCTAssertEqual("hello", ptn.projectField.stringValue)
        XCTAssertTrue(ptn.taskField.popupIsOpen)
        XCTAssertEqual("world", ptn.taskField.stringValue)

        // make first "project" field first responder
        window.makeFirstResponder(ptn.projectField)
        XCTAssertIdentical(ptn.projectField, autoCompletingField(containing: window.firstResponder))
        XCTAssertTrue(ptn.projectField.popupIsOpen)
        XCTAssertEqual("hello", ptn.projectField.stringValue)
        XCTAssertFalse(ptn.taskField.popupIsOpen)
        XCTAssertEqual("world", ptn.taskField.stringValue)
    }

    func openPtn(withData dataBuilder: (DataBuilder) -> Void) -> (PtnViewController, NSWindow) {
        AppDelegate.instance.mainMenu.open(.ptn, reason: .manual)
        guard let ptn = AppDelegate.instance.mainMenu.contentViewController as? PtnViewController else {
            XCTFail("main window controller was not a PtnViewController")
            fatalError()
        }
        ptn.override(model: loadModel(withData: dataBuilder))
        ptn.grabFocusNow()
        return (ptn, AppDelegate.instance.mainMenu.window!)
    }

    func autoCompletingField(containing responder: NSResponder?) -> AutoCompletingField? {
        var view = responder as? NSView
        while view != nil {
            if let result = view as? AutoCompletingField {
                return result
            }
            view = view?.superview
        }
        return nil
    }
}