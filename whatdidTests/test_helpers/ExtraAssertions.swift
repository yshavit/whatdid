// whatdidTests?

import XCTest

func XCTAssertEqualIgnoringOrder<T>(_ expression1: [T], _ expression2: [T]) where T : Hashable {
    let set1 = Set<T>(expression1)
    let set2 = Set<T>(expression2)
    XCTAssertEqual(set1, set2)
}
