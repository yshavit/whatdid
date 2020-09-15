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
    
    func schedule(at date: Date, _ block: @escaping () -> Void) -> ScheduledTask {
        let timer = Timer(fire: date, interval: 0, repeats: false, block: {_ in block()})
        timer.tolerance = SystemClockScheduler.TOLERANCE_SECONDS
        RunLoop.current.add(timer, forMode: .default)
        return TimerBasedScheduledTask(timer: timer)
    }
    
    func schedule(after: TimeInterval, _ block: @escaping () -> Void) -> ScheduledTask {
        let wakeupTime = DispatchWallTime.now() + .seconds(Int(after))
        let dispatchWorkItem = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(wallDeadline: wakeupTime, execute: dispatchWorkItem)
        return dispatchWorkItem
    }
}

private struct TimerBasedScheduledTask: ScheduledTask {
   let timer: Timer
   
   func cancel() {
       timer.invalidate()
   }
}

extension DispatchWorkItem: ScheduledTask {
    // ScheduledTask.cancel() is already defined
}
