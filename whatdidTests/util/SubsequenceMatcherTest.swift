// whatdidTests?

import XCTest
@testable import whatdid

class SubsequenceMatcherTest: XCTestCase {
    typealias Match = SubsequenceMatcher.Match
    
    func testUnicodePosition() {
        checkOne(lookFor: "is", inString: "the 😺 is happy", expect: [NSRange(location: 6, length: 2)])
    }
    
    func testUnicodeLength() {
        checkOne(lookFor: "😺", inString: "the 😺 is happy", expect: [NSRange(location: 4, length: 1)])
    }
    
    func testJustNeedleEmpty() {
        checkOne(lookFor: "", inString: "foo", expect: [])
    }

    func testJustLookInEmpty() {
        checkOne(lookFor: "a", inString: "", expect: [])
    }

    func testBothEmpty() {
        checkOne(lookFor: "", inString: "", expect: [])
    }

    func testNeedleMatches() {
        checkOne(lookFor: "fizz", inString: "for is zz top", expect: [
            NSRange(location: 0, length: 1), // f
            NSRange(location: 4, length: 1), // i
            NSRange(location: 7, length: 2)  // zz
        ])
    }

    func testNeedleDoesNotMatch() {
        checkOne(lookFor: "far", inString: "an f comes further", expect: [])
    }

    func testCaseInsensitivityWithLowercaseNeedle() {
        checkOne(lookFor: "lower", inString: "THE LOWER", expect: [NSRange(location: 4, length: 5)])
    }
    
    func testCaseInsensitivityWithUppercaseNeedle() {
        checkOne(lookFor: "UPPER", inString: "the upper", expect: [NSRange(location: 4, length: 5)])
    }

    func checkOne(lookFor needle: String, inString haystack: String, expect expected: [NSRange]) {
        XCTAssertEqual(SubsequenceMatcher.matches(lookFor: needle, inString: haystack), expected)
    }
    
    func match(for string: String, _ ranges: NSRange...) -> Match {
        return Match(string: string, matchedRanges: ranges)!
    }
}
