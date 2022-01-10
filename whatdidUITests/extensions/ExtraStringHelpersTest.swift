// whatdidTests?

import XCTest

class String_HelpersTest: XCTestCase {

    func testRot13() throws {
        XCTAssertEqual(
            "the quick brown fox jumped over the lazy dog".rot13,
            "gur dhvpx oebja sbk whzcrq bire gur ynml qbt")
        XCTAssertEqual(
            "THE QUICK BROWN FOX JUMPED OVER THE LAZY DOG".rot13,
            "GUR DHVPX OEBJA SBK WHZCRQ BIRE GUR YNML QBT")
        XCTAssertEqual(
            "\t1234☃",
            "\t1234☃")
    }
}
