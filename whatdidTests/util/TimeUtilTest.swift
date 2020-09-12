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
    
    func test_next_9amAnyDay() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withFullTime, .withColonSeparatorInTime]
        formatter.timeZone = DefaultScheduler.instance.timeZone
        let fri = formatter.date(from: "2020-09-04T10:00:00-04:00")!
        let sat = formatter.date(from: "2020-09-05T09:00:00-04:00")
        XCTAssertEqual(sat, TimeUtil.dateForTime(.next, hh: 09, mm: 00, assumingNow: fri, withTimeZone: usEastern))
    }
    
    func test_next_9amWeekday() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withFullTime, .withColonSeparatorInTime]
        formatter.timeZone = DefaultScheduler.instance.timeZone
        let fri = formatter.date(from: "2020-09-04T10:00:00-04:00")!
        let mon = formatter.date(from: "2020-09-07T09:00:00-04:00")
        XCTAssertEqual(mon, TimeUtil.dateForTime(.next, hh: 09, mm: 00, excludeWeekends: true, assumingNow: fri, withTimeZone: usEastern))
    }
    
    func test_formatSuccinct_soonToday() {
        checkFormatSuccinct(
            inUS: "2:30 am",
            inGB: "02:30",
            for: date(forIso8601: "2020-02-27T02:30:00"),
            assumingNow: date(forIso8601: "2020-02-27T02:00:00"))
    }
    
    func test_formatSuccinct_earlierToday() {
        checkFormatSuccinct(
            inUS: "2:30 am",
            inGB: "02:30",
            for: date(forIso8601: "2020-02-27T02:30:00"),
            assumingNow: date(forIso8601: "2020-02-27T22:00:00"))
    }
    
    func test_formatSuccinct_laterToday() {
        checkFormatSuccinct(
            inUS: "3:30 pm",
            inGB: "15:30",
            for: date(forIso8601: "2020-02-27T15:30:00"),
            assumingNow: date(forIso8601: "2020-02-27T02:00:00"))
    }
    
    // Check when the day component is the same, but it was a month ago. This is to make sure we're comparing components correctly.
    func test_formatSuccinct_oneMonthAgo() {
        checkFormatSuccinct(
            inUS: "2:30 am on Jan 27",
            inGB: "02:30 on 27 Jan",
            for: date(forIso8601: "2020-01-27T02:30:00"),
            assumingNow: date(forIso8601: "2020-02-27T02:30:00"))
    }
    
    func test_formatSuccinct_soonTomorrow() {
        checkFormatSuccinct(
            inUS: "11:30 am",
            inGB: "11:30",
            for: date(forIso8601: "2020-02-28T11:30:00"),
            assumingNow: date(forIso8601: "2020-02-27T23:59:00"))
    }
    
    func test_formatSuccinct_laterTomorrow() {
        checkFormatSuccinct(
            inUS: "tomorrow at 1:30 pm",
            inGB: "tomorrow at 13:30",
            for: date(forIso8601: "2020-02-28T13:30:00"),
            assumingNow: date(forIso8601: "2020-02-27T23:59:00"))
    }
    
    func test_formatSuccinct_thisWeek() {
        // note: Feb 27 was a Thursday in 2020; March 4 was a Wednesday
        checkFormatSuccinct(
            inUS: "Wednesday at 11:30 pm",
            inGB: "Wednesday at 23:30",
            for: date(forIso8601: "2020-03-04T23:30:00"),
            assumingNow: date(forIso8601: "2020-02-27T23:59:00"))
    }
    
    func test_formatSuccinct_nextWeek() {
        // note: 2020-02-27 was a Thursday; March 5 was the following Thursday
        checkFormatSuccinct(
            inUS: "11:30 am on Mar 5",
            inGB: "11:30 on 5 Mar",
            for: date(forIso8601: "2020-03-05T11:30:00"),
            assumingNow: date(forIso8601: "2020-02-27T23:59:00"))
    }
    
    func test_formatSuccinct_yesterday() {
        checkFormatSuccinct(
            inUS: "yesterday at 2:30 am",
            inGB: "yesterday at 02:30",
            for: date(forIso8601: "2020-02-27T02:30:00"),
            assumingNow: date(forIso8601: "2020-02-28T22:00:00"))
    }
    
    func test_formatSuccinct_beforeYesterday() {
        checkFormatSuccinct(
            inUS: "2:30 am on Feb 27",
            inGB: "02:30 on 27 Feb",
            for: date(forIso8601: "2020-02-27T02:30:00"),
            assumingNow: date(forIso8601: "2020-02-29T22:00:00"))
    }

    private var usEastern: TimeZone {
       return TimeZone(identifier: "US/Eastern")!
    }
    
    private func checkFormatSuccinct(inUS: String, inGB: String, for date: Date, assumingNow now: Date) {
        // purposefully using en_GB, since I'm in en_US
        XCTAssertEqual(
            inUS,
            TimeUtil.formatSuccinctly(date: date, assumingNow: now, timeZone: TimeZone.utc, locale: Locale(identifier: "en_US")))
        XCTAssertEqual(
            inGB,
            TimeUtil.formatSuccinctly(date: date, assumingNow: now, timeZone: TimeZone.utc, locale: Locale(identifier: "en_GB")))
    }
    
    private func date(forIso8601 string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.utc
        formatter.formatOptions = [ .withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime ]
        return formatter.date(from: string)!
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
