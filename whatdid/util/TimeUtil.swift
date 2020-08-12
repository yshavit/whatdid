// whatdid?

import Foundation

class TimeUtil {
    private init() {
        // utility class
    }
    
    private static let SEC_IN_MIN = 60
    private static let SEC_IN_HR = TimeUtil.SEC_IN_MIN * 60
    private static let SEC_IN_DAY = TimeUtil.SEC_IN_HR * 24 // assume 24h day, since that's how people usually think
    
    static func daysHoursMinutes(for input: TimeInterval) -> String {
        var interval = Int(input) // TODO be slightly better with rounding, if we care
        
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
        let mins = interval / SEC_IN_MIN
        result += "\(mins)m"
        
        return result
    }
    
    static func sameDay(_ day1: Date, _ day2: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: day1) == cal.component(.year, from: day2)
            && cal.component(.month, from: day1) == cal.component(.month, from: day2)
            && cal.component(.day, from: day1) == cal.component(.day, from: day2)
    }
    
    static func dateForTime(_ direction: TimeDirection, hh: Int, mm: Int, assumingNow: Date? = nil) -> Date {
        let now = assumingNow ?? DefaultScheduler.instance.now
        var cal = Calendar.current
        cal.timeZone = DefaultScheduler.instance.timeZone
        var result = cal.date(bySettingHour: hh, minute: mm, second: 00, of: now)
        NSLog("Finding %@ time at %02d:%02d. Now=%@, initial result = %@", direction.rawValue, hh, mm, now.debugDescription, result.debugDescription)
        switch direction {
        case .previous:
            // We want a result < now, so if result > now, decrement it by a day
            if let actualResult = result, actualResult >= now {
                result = cal.date(byAdding: .day, value: -1, to: actualResult)
                NSLog("adjusting -1 day: %@", result.debugDescription)
            }
        case .next:
            // We want a result > now, so if result < now, increment it by a day
            if let actualResult = result, actualResult <= now {
                result = cal.date(byAdding: .day, value: 1, to: actualResult)
                NSLog("adjusting +1 day: %@", result.debugDescription)
            }
        }
        return result!
    }
    
    enum TimeDirection : String {
        case previous
        case next
    }
}
