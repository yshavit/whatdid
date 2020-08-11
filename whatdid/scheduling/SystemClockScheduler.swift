// whatdid?

import Cocoa

class SystemClockScheduler: Scheduler {
    static let TOLERANCE_SECONDS : TimeInterval = 30
    
    var now: Date {
        return Date()
    }
    
    func schedule(at date: Date, _ block: @escaping () -> Void) {
        let tolerence = SystemClockScheduler.TOLERANCE_SECONDS * 2
        let adjustedDate = date.addingTimeInterval(-tolerence)
        let timer = Timer(fire: adjustedDate, interval: 0, repeats: false, block: {_ in block()})
        timer.tolerance = tolerence
        RunLoop.current.add(timer, forMode: .default)
    }
    
    func schedule(after: TimeInterval, _ block: @escaping () -> Void) {
        let wakeupTime = DispatchWallTime.now() + .seconds(Int(after))
        DispatchQueue.main.asyncAfter(wallDeadline: wakeupTime, execute: block)
    }
    
    
}
