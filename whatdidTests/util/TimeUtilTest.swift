// whatdidTests?

import XCTest
@testable import whatdid

class TimeUtilTest: XCTestCase {
    
    func test_60s() {
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: 60), "1m")
    }
    
    func test_10s() {
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: 10), "0m")
    }
    
    /// We round down; see gh issue #74
    func test_31s() {
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: 31), "0m")
    }
    
    func test_1h23m() {
        let t = secondsFor(hrs: 1) + secondsFor(mins: 23)
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: t), "1h 23m")
    }
    
    
    func test_1d2h34m() {
        let t = secondsFor(days: 1) + secondsFor(hrs: 2) + secondsFor(mins: 34)
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: t), "1d 2h 34m")
    }
    
    /// We don't print out weeks
    func test_8d() {
        let t = secondsFor(days: 8)
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: t), "8d 0h 0m")
    }
    
    /// We don't print out months
    func test_35d() {
        let t = secondsFor(days: 35)
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: t), "35d 0h 0m")
    }
    
    /// We don't print out years
    func test_366d() {
        let t = secondsFor(days: 366)
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: t), "366d 0h 0m")
    }
    
    private func secondsFor(mins: Int) -> TimeInterval {
        return Double(mins) * 60.0
    }
    
    private func secondsFor(hrs: Int) -> TimeInterval {
        return secondsFor(mins: hrs * 60)
    }
    
    private func secondsFor(days: Int) -> TimeInterval {
        return secondsFor(hrs: days * 24) // assume 24-hour days
    }
}
