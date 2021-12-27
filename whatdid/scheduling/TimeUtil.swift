// whatdid?

import Foundation

class TimeUtil {
    private init() {
        // utility class
    }
    
    private static let SEC_IN_HR = 60 * 60
    private static let SEC_IN_DAY = TimeUtil.SEC_IN_HR * 24 // assume 24h day, since that's how people usually think
    
    static func daysHoursMinutes(for input: TimeInterval) -> String {
        var interval = Int(input)
        
        var result = ""
        
        if interval < 0 {
            result += "-"
            interval *= -1
        }
        let days = interval / SEC_IN_DAY
        if days > 0 {
            result += "\(days)d "
            interval -= (days * SEC_IN_DAY)
        }
        let hrs = interval / SEC_IN_HR
        if hrs > 0 || days > 0 {
            result += "\(hrs)h "
            interval -= (hrs * SEC_IN_HR)
        }
        let minsDouble = Double(interval) / 60
        result += "\(Int(minsDouble.rounded()))m"
        
        return result
    }
    
    static func sameDay(_ day1: Date, _ day2: Date) -> Bool {
        let cal = DefaultScheduler.instance.calendar
        return cal.component(.year, from: day1) == cal.component(.year, from: day2)
            && cal.component(.month, from: day1) == cal.component(.month, from: day2)
            && cal.component(.day, from: day1) == cal.component(.day, from: day2)
    }
    
    static func dateForTime(_ direction: TimeDirection, hh: Int, mm: Int, excludeWeekends: Bool = false, assumingNow: Date? = nil, withTimeZone tz: TimeZone? = nil) -> Date {
        let now = assumingNow ??
            DefaultScheduler.instance.now.addingTimeInterval(TimeInterval(direction.timeDelta))
        var cal = DefaultScheduler.instance.calendar
        cal.timeZone = tz ?? DefaultScheduler.instance.timeZone
        var result = cal.date(bySettingHour: hh, minute: mm, second: 00, of: now)
        switch direction {
        case .previous:
            // We want a result < now, so if result > now, decrement it by a day
            if let actualResult = result, actualResult >= now {
                result = cal.date(byAdding: .day, value: -1, to: actualResult)
            }
        case .next:
            // We want a result > now, so if result < now, increment it by a day
            if let actualResult = result, actualResult <= now {
                result = cal.date(byAdding: .day, value: 1, to: actualResult)
            }
        }
        while excludeWeekends, let actualResult = result, cal.isDateInWeekend(actualResult) {
            result = cal.date(byAdding: .day, value: direction.timeDelta, to: actualResult)
        }
        return result!
    }
    
    static func formatSuccinctly(date: Date, assumingNow: Date? = nil, timeZone: TimeZone? = nil, locale: Locale? = nil) -> String {
        let now = assumingNow ?? DefaultScheduler.instance.now
        let tz = timeZone ?? DefaultScheduler.instance.timeZone
        
        let daysApart = TimeUtil.daysBetween(now: now, andDate: date, using: tz)
        
        let formatString: [FormatSegment]
        if daysApart == 0 {
            formatString = [.hourAndMinute]
        } else if daysApart == -1 {
            formatString = [.literal("yesterday at "), .hourAndMinute]
        } else if daysApart == 1 {
            formatString = date.timeIntervalSince(now) <= 43200
                ? [.hourAndMinute] // The date is tomorrow, but within 12 hours of now
                : [.literal("tomorrow at "), .hourAndMinute]
        } else if daysApart > 1 && daysApart <= 6 {
            formatString = [.fromDate("EEEE"), .literal(" at "), .hourAndMinute]
        } else {
            formatString = [.hourAndMinute, .literal(" on "), .fromDate("dMMM")]
        }
        
        let formatter = DateFormatter()
        formatter.locale = locale ?? NSLocale.current
        formatter.timeZone = tz
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        
        var result = ""
        for segment in formatString {
            switch segment {
            case let .literal(literalValue):
                result += literalValue
            case let .fromDate(format):
                formatter.setLocalizedDateFormatFromTemplate(format)
                result += formatter.string(from: date)
            case .hourAndMinute:
                formatter.setLocalizedDateFormatFromTemplate("j:mm a")
                result += formatter.string(from: date)
            }
        }
        return result
    }
    
    static func daysBetween(now: Date, andDate then: Date, using timeZone: TimeZone) -> Int {
        var calendar = DefaultScheduler.instance.calendar
        calendar.timeZone = timeZone
        let nowStart = calendar.startOfDay(for: now)
        let thenStart = calendar.startOfDay(for: then)
        return calendar.dateComponents([.day], from: nowStart, to: thenStart).day ?? 0
    }
    
    static func roundUp(_ date: Date, bufferedByMinute buffer: Int, toClosestMinute intervalMinutes: Int) -> Date {
        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        let secondsSinceEpoch = date.timeIntervalSince1970 + TimeInterval(buffer * 60)
        let intervalsSinceEpoch = secondsSinceEpoch / intervalSeconds
        let intervalsRoundedUp = intervalsSinceEpoch.rounded(.up)
        return Date(timeIntervalSince1970: intervalsRoundedUp * intervalSeconds)
    }
    
    enum TimeDirection : String {
        case previous
        case next
        
        fileprivate var timeDelta: Int {
            switch self {
            case .previous:
                return -1
            case .next:
                return 1
            }
        }
    }
    
    private enum FormatSegment {
        case hourAndMinute
        case fromDate(String)
        case literal(String)
    }
}
