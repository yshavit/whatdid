// whatdid?

import Foundation

class TimeUtil {
    private init() {
        // utility class
    }
    
    static func daysHoursMinutes(for input: TimeInterval, showSeconds: Bool = false) -> String {
        let breakdown = TimeIntervalBreakdown(from: input, roundedTo: showSeconds ? .seconds : .minutes)
        return breakdown.description
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
            formatString = [.fromDate("dMMM"), .literal(" at "), .hourAndMinute]
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
    
    static func daysBetween(now: Date, andDate then: Date, using timeZone: TimeZone? = nil) -> Int {
        var calendar = DefaultScheduler.instance.calendar
        if let timeZone = timeZone {
            calendar.timeZone = timeZone
        }
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

func timed(_ action: String, _ block: () -> Void) {
    #if UI_TEST
    let start = DispatchTime.now().uptimeNanoseconds
    defer {
        DispatchQueue.main.async(group: nil, qos: .userInteractive, flags: []) {
            let end = DispatchTime.now().uptimeNanoseconds
            let nanos = end - start
            let millis = nanos / 1000000
            wdlog(.info, "** TIMER: %@ => %d ms", action, millis)
        }
    }
    #endif
    block()
}

func timeUnitsToInterval(_ units: [TimeUnit: Int]) -> TimeInterval {
    return TimeInterval(
        units
            .map({(unit, value) in value * unit.toSeconds()})
            .reduce(0, +)
    )
}

enum TimeUnit: CaseIterable, CustomStringConvertible {
    
    case days
    case hours
    case minutes
    case seconds
    
    var description: String {
        switch self {
        case .days:
            return "d"
        case .hours:
            return "h"
        case .minutes:
            return "m"
        case .seconds:
            return "s"
        }
    }
    
    func toSeconds(hoursPerDay: Int = 24) -> Int { // assume 24h days for now
        let SECONDS_PER_MINUTE = 60
        let SECONDS_PER_HOUR = SECONDS_PER_MINUTE * 60
        
        if self == .days {
            return SECONDS_PER_HOUR * hoursPerDay
        } else if self == .hours {
            return SECONDS_PER_HOUR
        } else if self == .minutes {
            return SECONDS_PER_MINUTE
        } else {
            assert(self == .seconds, "unrecognized unit")
            return 1
        }
    }
}

struct TimeIntervalBreakdown: CustomStringConvertible {
    
    let negative: Bool
    let components: [TimeUnit: Int]
    
    init(from input: TimeInterval, roundedTo roundTo: TimeUnit = .seconds) {
        
        var interval = Int(input)
        
        if interval < 0 {
            negative = true
            interval *= -1
        } else {
            negative = false
        }
        
        var components: [TimeUnit: Int] = [:]
        for unit in TimeUnit.allCases {
            let secondsPerUnit = unit.toSeconds()
            if unit == roundTo {
                components[unit] = Int(
                    (Double(interval) / Double(secondsPerUnit)).rounded()
                )
                break
            } else {
                let value = interval / secondsPerUnit
                interval -= (value * secondsPerUnit)
                components[unit] = value
            }
        }
        self.components = components
    }
    
    func componentInterval(for unit: TimeUnit) -> Int {
        return components[unit] ?? 0
    }
    
    var description: String {
        let negation = negative ? "-" : ""
        return negation + componentsInOrder.map(
            {(unit, magnitude) in "\(magnitude)\(unit.description)"}
        ).joined(separator: " ")
    }
    
    private var componentsInOrder: [(TimeUnit, Int)] {
        let entries: [(TimeUnit, Int)] = TimeUnit.allCases.compactMap({ unit in
            if let magnitude = components[unit] {
                return (unit, magnitude)
            } else {
                return nil
            }
        })
        guard let mostPreciseUnit = entries.last?.0 else {
            return [] // shouldn't happen, but let's be safe
        }
        let withoutLeadingZeros = entries.drop(while: {_, magnitude in magnitude == 0})
        if withoutLeadingZeros.isEmpty {
            return [(mostPreciseUnit, 0)]
        }
        return Array(withoutLeadingZeros)
    }
}
