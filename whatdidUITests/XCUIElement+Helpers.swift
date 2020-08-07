// whatdidUITests?

import XCTest

extension XCUIElement {
    func hasFocus() -> Bool {
        let hasKeyboardFocus = (self.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
        return hasKeyboardFocus
    }
    
    func backtab() {
        typeKey(.tab, modifierFlags: .shift)
    }
}
