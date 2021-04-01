// whatdidTests?

import XCTest
@testable import whatdid

class NSRange_HelpersTest: XCTestCase {

    func testEmpty() {
        XCTAssertEqual(
            [],
            NSRange.arrayFrom(ints: []))
    }
    
    func testOne() {
        XCTAssertEqual(
            [NSRange(location: 1, length: 1)],
            NSRange.arrayFrom(ints: [1]))
    }
    
    func testSparse() {
        XCTAssertEqual(
            [NSRange(location: 1, length: 1), NSRange(location: 3, length: 1)],
            NSRange.arrayFrom(ints: [1, 3]))
    }
    
    func testSequential() {
        XCTAssertEqual(
            [NSRange(location: 1, length: 3)],
            NSRange.arrayFrom(ints: [1, 2, 3]))
    }
    
    /// Not really different arrayFrom sparse + sequential, but eh, why not
    func testMixed() {
        XCTAssertEqual(
            [NSRange(location: 1, length: 2), NSRange(location: 5, length: 1)],
            NSRange.arrayFrom(ints: [1, 2, 5]))
    }
    
    func testAllDuplicateNumbers() {
        XCTAssertEqual(
            [NSRange(location: 1, length: 1)],
            NSRange.arrayFrom(ints: [1, 1, 1]))
    }
    
    func testDuplicateNumbersThenSequential() {
        XCTAssertEqual(
            [NSRange(location: 1, length: 2)],
            NSRange.arrayFrom(ints: [1, 1, 2]))
    }
    
    func testDuplicateNumbersThenSparse() {
        XCTAssertEqual(
            [NSRange(location: 1, length: 1), NSRange(location: 3, length: 1)],
            NSRange.arrayFrom(ints: [1, 1, 3]))
    }
    
    func testNumbersOutOfOrder() {
        XCTAssertEqual(
            [NSRange(location: 1, length: 3)],
            NSRange.arrayFrom(ints: [2, 3, 1]))
    }
    
    // Not expected, but should work anyway
    func testNegatives() {
        XCTAssertEqual(
            [NSRange(location: -2, length: 4), NSRange(location: 3, length: 1)],
            NSRange.arrayFrom(ints: [-2, -1, 0, 1, 3]))
    }
}
