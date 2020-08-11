// whatdid?
#if UI_TEST
import Foundation

class ManualTickScheduler: Scheduler {
    private var _now = Date(timeIntervalSince1970: 0)
    private var events = [(Date, () -> Void)]()
    
    func schedule(at date: Date, _ block: @escaping () -> Void) {
        if date == _now {
            enqueueAction(block)
        } else if date > _now {
            events.append((date, block))
        } else {
            NSLog("ignoring event because it's in the past (\(date))")
        }
    }
    
    func schedule(after time: TimeInterval, _ block: @escaping () -> Void) {
        schedule(at: _now.addingTimeInterval(time), block)
    }
    
    var now: Date {
        get {
            return _now
        }
        set (value) {
            _now = value
            // I'm going to go for just the easy approach; efficiency isn't a concern here.
            events.filter { $0.0 <= value } .forEach { self.enqueueAction($0.1) }
            events.removeAll(where: { $0.0 <= value})
        }
    }
    
    private func enqueueAction(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

}

#endif
