// whatdid?

import Cocoa

class SystemClockScheduler: Scheduler {
    static let TOLERANCE_SECONDS : TimeInterval = 30
    
    var now: Date {
        return Date()
    }
    
    var timeZone: TimeZone {
        return TimeZone.autoupdatingCurrent
    }
    
    func schedule(at date: Date, _ block: @escaping () -> Void) -> ScheduledTask {
        let tolerence = SystemClockScheduler.TOLERANCE_SECONDS * 2
        let adjustedDate = date.addingTimeInterval(-tolerence)
        let timer = Timer(fire: adjustedDate, interval: 0, repeats: false, block: {_ in block()})
        timer.tolerance = tolerence
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
