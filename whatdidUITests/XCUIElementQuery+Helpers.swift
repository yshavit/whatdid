// whatdidUITests?

import XCTest

extension XCUIElementQuery {
    /// Returns whether at least one element matches the given predicate
    ///
    /// This function can include predicates that aren't XCUIElement-codable (and which therefore can't be matched via `matching(predicate)`).
    /// Since it stops as soon as it hits the limit, it can be faster than reifying the whole query to a `[XCUIElement]` and then filtering that array.
    func hasAtLeastOneElement(where predicate: (XCUIElement) -> Bool) -> Bool {
        XCTestCase.group("XCUIElementQuery.hasAtLeastOneElement") {
            for i in 0... {
                let possibleAnswer = XCTestCase.group("checking element #\(i)") {() -> Bool? in
                    let e = element(boundBy: i)
                    guard e.exists else {
                        return false
                    }
                    if predicate(e) {
                        return true
                    }
                    return nil
                }
                if let answer = possibleAnswer {
                    return answer
                }
            }
            return false
        }
    }
}
