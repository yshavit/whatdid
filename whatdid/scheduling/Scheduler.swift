// whatdid?

import Foundation

protocol Scheduler {
    var now: Date { get }
    var timeZone: TimeZone { get }
    @discardableResult func schedule(at: Date, _ block: @escaping () -> Void) -> ScheduledTask
    @discardableResult func schedule(after: TimeInterval, _ block: @escaping () -> Void) -> ScheduledTask
}

protocol ScheduledTask {
    func cancel()
}

extension Date {
    var timeIntervalSinceWhatdidNow: TimeInterval {
        return timeIntervalSince1970 - DefaultScheduler.instance.now.timeIntervalSince1970
    }
}
