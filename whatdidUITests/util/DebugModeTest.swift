// whatdidTests?
import XCTest
@testable import whatdid

class DebugModeTest: XCTestCase {

    func testToLaunchArgAndBack() {
        let launchArg = DebugMode.buttonWithClosure.toLaunchArgument()
        let maybeParsed = DebugMode(fromStringIfWithPrefix: launchArg)
        XCTAssertEqual(maybeParsed, DebugMode.buttonWithClosure)
    }

    func testDebugPrefixWithoutMode() {
        let maybeParsed = DebugMode(fromStringIfWithPrefix: DebugMode.DEBUG_MODE_ARG_PREFIX)
        XCTAssertNil(maybeParsed)
    }
    
    func testDebugPrefixToBogusMode() {
        let maybeParsed = DebugMode(fromStringIfWithPrefix: DebugMode.DEBUG_MODE_ARG_PREFIX + "notARealMode")
        XCTAssertNil(maybeParsed)
    }
    
    func testWithNotThePrefix() {
        let maybeParsed = DebugMode(fromStringIfWithPrefix: "foobar")
        XCTAssertNil(maybeParsed)
    }
    
    func testEmptyString() {
        let maybeParsed = DebugMode(fromStringIfWithPrefix: "")
        XCTAssertNil(maybeParsed)
    }
    
}
