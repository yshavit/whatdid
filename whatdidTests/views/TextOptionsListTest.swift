// whatdidTests?

import XCTest
@testable import whatdid

class TextOptionsListTest: XCTestCase {
    
    private let callbacks = DummyCallbacks()
    private let view = TextOptionsList()

    override func setUpWithError() throws {
        view.willShow(callbacks: callbacks)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAutocompleteChangesSelection() throws {
        view.options = ["one", "two"]
        view.moveSelection(.up)
        XCTAssertEqual("two", view.selectedText) // sanity check
        let autocompleteSuggestion = view.onTextChanged(to: "on")
        XCTAssertEqual("one", autocompleteSuggestion)
        XCTAssertEqual("one", view.selectedText)
    }
    
    func testAutocompleteNegatesSelection() throws {
        view.options = ["one", "two"]
        view.moveSelection(.up)
        XCTAssertEqual("two", view.selectedText) // sanity check
        let autocompleteSuggestion = view.onTextChanged(to: "th")
        XCTAssertEqual("th", autocompleteSuggestion)
        XCTAssertNil(view.selectedText)
    }
    
    func testAutocompleteNegatesSelectionOneLetterAtATime() throws {
        view.options = ["one", "two"]
        view.moveSelection(.up)
        XCTAssertEqual("two", view.selectedText) // sanity check
        
        var autocompleteSuggestion = view.onTextChanged(to: "t")
        XCTAssertEqual("two", autocompleteSuggestion)
        XCTAssertEqual("two", view.selectedText)
        
        autocompleteSuggestion = view.onTextChanged(to: "th")
        XCTAssertEqual("th", autocompleteSuggestion)
        XCTAssertNil(view.selectedText)
    }
    
    func testAutocompleteSetsSelection() throws {
        view.options = ["one", "two"]
        XCTAssertNil(view.selectedText) // sanity check
        var autocompleteSuggestion = view.onTextChanged(to: "o")
        XCTAssertEqual("one", autocompleteSuggestion)
        XCTAssertEqual("one", view.selectedText)
        
        autocompleteSuggestion = view.onTextChanged(to: "on")
        XCTAssertEqual("one", autocompleteSuggestion)
        XCTAssertEqual("one", view.selectedText)
    }
    
    func testAutoCompleteKeepsSelectionWhenPossible() {
        view.options = ["one a", "one b", "one c"]
        view.moveSelection(.down)
        view.moveSelection(.down)
        XCTAssertEqual("one b", view.selectedText) // sanity check
        
        let autocompleteSuggestion = view.onTextChanged(to: "one")
        XCTAssertEqual("one b", autocompleteSuggestion)
        XCTAssertEqual("one b", view.selectedText)
    }
    
    private class DummyCallbacks: TextFieldWithPopupCallbacks {
        func contentSizeChanged() {
            // nothing
        }
        
        func scroll(to bounds: NSRect, within: NSView) {
            // nothing
        }
        
        func setText(to string: String) {
            // nothing
        }
    }
}
