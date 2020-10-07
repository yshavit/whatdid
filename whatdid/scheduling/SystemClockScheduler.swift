// whatdid?

import Cocoa

class SystemClockScheduler: Scheduler {
    static let TOLERANCE_SECONDS : TimeInterval = 60
    
    var now: Date {
        return Date()
    }
    
    var timeZone: TimeZone {
        return TimeZone.autoupdatingCurrent
    }
    
    func schedule(_ description: String, at date: Date, _ block: @escaping () -> Void) -> ScheduledTask {
        NSLog("Scheduling \(description) at \(date)")
        let dispatchWorkItem = DispatchWorkItem(block: block)
        let wallDeadline = DispatchWallTime.now() + date.timeIntervalSince(now)
        DispatchQueue.main.asyncAfter(wallDeadline: wallDeadline, execute: dispatchWorkItem)
        return dispatchWorkItem
    }
    
    func schedule(_ description: String, after: TimeInterval, _ block: @escaping () -> Void) -> ScheduledTask {
        NSLog("Scheduling \(description) after \(after)s")
        let wakeupTime = DispatchWallTime.now() + .seconds(Int(after))
        let dispatchWorkItem = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(wallDeadline: wakeupTime, execute: dispatchWorkItem)
        return dispatchWorkItem
    }
}

extension DispatchWorkItem: ScheduledTask {
    // ScheduledTask.cancel() is already defined
}
