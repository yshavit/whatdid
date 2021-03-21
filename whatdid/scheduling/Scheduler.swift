// whatdid?

import Foundation

protocol Scheduler {
    var now: Date { get }
    var timeZone: TimeZone { get }
    @discardableResult func schedule(_ description: String, at: Date, _ block: @escaping () -> Void) -> ScheduledTask
}

extension Scheduler {
    @discardableResult func schedule(_ description: String, after: TimeInterval, _ block: @escaping () -> Void) -> ScheduledTask {
        return schedule(description, at: now + after, block)
    }
    
    func timeInterval(since date: Date) -> TimeInterval {
        return now.timeIntervalSince(date)
    }
}

protocol ScheduledTask {
    func cancel()
}

extension Date {
    var timeIntervalSinceWhatdidNow: TimeInterval {
        return timeIntervalSince1970 - DefaultScheduler.instance.now.timeIntervalSince1970
    }
}
