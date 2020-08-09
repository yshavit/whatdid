// whatdidUITests?

import XCTest

extension XCUIElement {
    
    func grabFocus() {
        if !hasFocus {
            click()
        }
    }
    
    var hasFocus: Bool {
        return (self.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }
    
    var focusedChild: XCUIElement {
        get {
            let focusedElems = children(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus = true")).allElementsBoundByIndex
            XCTAssertEqual(focusedElems.count, 1)
            return focusedElems[0]
        }
    }
    
    var stringValue: String {
        return value as! String
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
