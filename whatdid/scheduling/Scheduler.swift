// whatdid?

import Foundation

protocol Scheduler {
    var now: Date { get }
    var timeZone: TimeZone { get }
    func schedule(at: Date, _ block: @escaping () -> Void)
    func schedule(after: TimeInterval, _ block: @escaping () -> Void)
}

extension Date {
    var timeIntervalSinceWhatdidNow: TimeInterval {
        return timeIntervalSince1970 - DefaultScheduler.instance.now.timeIntervalSince1970
    }
}
