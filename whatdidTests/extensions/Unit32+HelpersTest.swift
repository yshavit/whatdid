// whatdidTests?

import XCTest

class Unit32_HelpersTest: XCTestCase {

    func test0() {
        check(that: 0, equals: 0.0)
    }
    
    func testMax() {
        check(that: UInt32.max, equals: 1.0)
    }
    
    func testHalf() {
        check(that: UInt32.max / 2, equals: 0.5)
    }

    private func check(that asUnit: UInt32, equals expected: Float) {
        let actual = asUnit.asUnitFloat
        XCTAssertEqual(expected, actual)
    }
}
