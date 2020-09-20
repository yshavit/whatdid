// whatdidTests?

import XCTest
@testable import whatdid

class PrefsTest: XCTestCase {

    func testEncodingBackAndForthNormal() {
        let hhmmOrig = HoursAndMinutes(hours: 12, minutes: 30)
        let hhmmBack = HoursAndMinutes(encoded: hhmmOrig.encoded)
        check(actual: hhmmBack, expectedHours: 12, expectedMinutes: 30)
    }
    
    func testEncodingNegativeAndBig() {
        let hhmmOrig = HoursAndMinutes(hours: -543, minutes: 21)
        let hhmmBack = HoursAndMinutes(encoded: hhmmOrig.encoded)
        check(actual: hhmmBack, expectedHours: -543, expectedMinutes: 21)
    }
    
    func testMinutesTooBig() {
        let hhmmOrig = HoursAndMinutes(hours: 1, minutes: 60)
        let hhmmBack = HoursAndMinutes(encoded: hhmmOrig.encoded)
        check(actual: hhmmBack, expectedHours: 1, expectedMinutes: 0)
    }
    
    private func check(actual: HoursAndMinutes, expectedHours: Int, expectedMinutes: Int) {
        var actualHours: Int?
        var actualMinutes: Int?
        actual.read() {hh, mm in
            actualHours = hh
            actualMinutes = mm
        }
        XCTAssertEqual(expectedHours, actualHours)
        XCTAssertEqual(expectedMinutes, actualMinutes)
    }

}
