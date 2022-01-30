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
    
    func test_31s() {
        XCTAssertEqual(TimeUtil.daysHoursMinutes(for: 31), "1m")
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
            inUS: "Jan 27 at 2:30 am",
            inGB: "27 Jan at 02:30",
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
            inUS: "Mar 5 at 11:30 am",
            inGB: "5 Mar at 11:30",
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
            inUS: "Feb 27 at 2:30 am",
            inGB: "27 Feb at 02:30",
            for: date(forIso8601: "2020-02-27T02:30:00"),
            assumingNow: date(forIso8601: "2020-02-29T22:00:00"))
    }
    
    func testRoundUp_given_0m_bufferedBy_10m_to_30m_expect_30m00s() {
        runRoundUpTest()
    }
    
    func testRoundUp_given_19m59s_bufferedBy_10m_to_30m_expect_30m00s() {
        runRoundUpTest()
    }
    
    func testRoundUp_given_20m_bufferedBy_10m_to_30m_expect_30m00s() {
        runRoundUpTest()
    }

    func testRoundUp_given_20m01s_bufferedBy_10m_to_30m_expect_1h00m00s() {
        runRoundUpTest()
    }
    
    func testRoundUp_given_0m00s_bufferedBy_5m_to_15m_expect_15m00s() {
        runRoundUpTest()
    }
    
    func testRoundUp_given_10m00s_bufferedBy_5m_to_15m_expect_15m00s() {
        runRoundUpTest()
    }
    
    func testRoundUp_given_10m01s_bufferedBy_5m_to_15m_expect_30m00s() {
        runRoundUpTest()
    }
    
    /// This tests `TimeUtil.roundUp` by deriving data from the test method's name.
    ///
    /// This method expects the test name to include `given_<t>_bufferedBy_#_to_#_expect<t>`, where
    /// `<t>` is of the form `#h#m#s`, with each component optional. For instance, `given_30m40s`.
    /// The method will take the starting date as epoch + "given", and then pass it to `roundUp` with the specified buffer
    /// and round-to. It then expects a date, specified similarly as epoch + "expect".
    ///
    /// For example, a test named:
    ///
    ///     testRoundUp_given_1h_bufferedBy_3m_to_4m_expect_5h6s
    ///
    /// would call
    ///
    ///     TimeUtil.roundUp(1970-01-01T00:01:00Z, bufferedByMinute: 3, toClosestMinute: 4)
    ///
    /// and expect a result of `1970-01-01T05:00:06Z`
    private func runRoundUpTest() {
        let testName = testRun!.test.name
        var regex: NSRegularExpression?
        do {
            /// Creates an optional group that captures `\d` followed by `unit`, named `unit`.
            func digits(_ unit: String) -> String {
                return "(?:(?<\(unit)>\\d+)\(unit))?"
            }
            try regex = NSRegularExpression(pattern: "(?<key>[a-zA-Z]+)_" + digits("h") + digits("m") + digits("s"))
        } catch {
            XCTFail("bad regex: \(error)")
        }
        /// Find all instances of `foo_1h2m3s`, where the h/m/s components are all optional
        var matches = [String : (hh:Int, mm:Int, ss:Int)]()
        for match in regex!.matches(in: testName, range: name.fullNsRange()) {
            let key = testName.substring(of: match.range(withName: "key"))!
            let hh = testName.substring(of: match.range(withName: "h")) ?? "0"
            let mm = testName.substring(of: match.range(withName: "m")) ?? "0"
            let ss = testName.substring(of: match.range(withName: "s")) ?? "0"
            matches[key] = (hh: Int(hh)!, mm: Int(mm)!, ss: Int(ss)!)
        }
        // Extract the test case from the matches
        let given = matches["given"]!
        let givenDate = date(hh: given.hh, mm: given.mm, ss: given.ss)
        let bufferedBy = matches["bufferedBy"]!
        let to = matches["to"]!
        let expect = matches["expect"]!
        
        let actual = TimeUtil.roundUp(
            givenDate,
            bufferedByMinute: bufferedBy.mm,
            toClosestMinute: to.mm)
        let msg = "rounding \(given) + \(bufferedBy)m to \(to)m"
        XCTAssertEqual(date(hh: expect.hh, mm: expect.mm, ss: expect.ss), actual, msg)
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
    
    private func date(hh: Int = 0, mm: Int, ss: Int = 0) -> Date {
        return Date(timeIntervalSince1970: secondsFor(hrs: hh) + secondsFor(mins: mm) + TimeInterval(ss))
    }
    
    private func components(of date: Date) -> (hh: Int, mm: Int, ss: Int) {
        var secondsRemaining = date.timeIntervalSince1970
        let hours = Int(secondsRemaining / 3600.0)
        secondsRemaining -= Double(hours) * 3600.0
        let minutes = Int(secondsRemaining / 60.0)
        secondsRemaining -= Double(minutes) * 60.0
        XCTAssertEqual(secondsRemaining, secondsRemaining.rounded(), "test failure: seconds wasn't whole for some reason")
        return (hh: hours, mm: minutes, ss: Int(secondsRemaining))
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

fileprivate extension String {
    func substring(of range: NSRange) -> String? {
        guard let stringRange = Range(range, in: self) else {
            return nil
        }
        let asSubstring = self[stringRange.lowerBound..<stringRange.upperBound]
        return String(asSubstring)
    }
}
