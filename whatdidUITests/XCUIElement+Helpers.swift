// whatdidUITests?

import XCTest

extension XCUIElement {
    func hasFocus() -> Bool {
        
        let hasKeyboardFocus = (self.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
        return hasKeyboardFocus
    }
    
    var focusedChild: XCUIElement {
        get {
            let focusedElems = children(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus = true")).allElementsBoundByIndex
            XCTAssertEqual(focusedElems.count, 1)
            return focusedElems[0]
        }
    }
    
    func clearTextField() {
        click()
        typeKey(.upArrow)
        typeKey(.downArrow, modifierFlags: .shift)
        typeKey(.delete)
    }
    
    func replaceTextFieldContents(with newContents: String) {
        clearTextField()
        typeText(newContents)
    }
    
    func backtab() {
        typeKey(.tab, modifierFlags: .shift)
    }
    
    /// Basically a safer version of `isHittable` that also checks if the element exists at all.
    var isVisible: Bool {
        get {
            return exists && isHittable
        }
    }
    
    func typeKey(_ key: XCUIKeyboardKey) {
        typeKey(key, modifierFlags: [])
    }
    
    func assertVisible() {
        _ = frame // just trying to get it will fail if the element isn't visible
    }
}
