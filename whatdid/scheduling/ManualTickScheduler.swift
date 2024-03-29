// whatdid?
#if UI_TEST
import Foundation

class ManualTickScheduler: Scheduler {
    private var _now = Date(timeIntervalSince1970: 0)
    private var events = [WorkItem]()
    private var listeners = [(Date) -> Void]()
    
    func reset() {
        _now = Date(timeIntervalSince1970: 0)
        listeners.forEach { $0(_now) }
        events = []
    }
    
    @discardableResult func schedule(_ description: String, at date: Date, _ block: @escaping () -> Void) -> ScheduledTask {
        wdlog(.debug, "Scheduling %{public}@ at %{public}@ (t+%.0f)", description, date as NSDate, date.timeIntervalSinceWhatdidNow)
        if date == _now {
            enqueueAction(block)
            return NoopScheduledItem()
        } else if date > _now {
            let uuid = UUID()
            events.append(WorkItem(id: uuid, fireAt: date, block: block))
            return ManualScheduledItem(parent: self, id: uuid)
        } else {
            wdlog(.warn, "ignoring event because it's in the past (%{public}@)", date as NSDate)
            return NoopScheduledItem()
        }
    }
    
    func addListener(_ listener: @escaping (Date) -> Void) {
        listeners.append(listener)
    }
    
    var now: Date {
        get {
            return _now
        }
        set (value) {
            _now = value
            // I'm going to go for just the easy approach; efficiency isn't a concern here.
            events.filter { $0.fireAt <= value } .forEach { self.enqueueAction($0.block) }
            events.removeAll(where: { $0.fireAt <= value})
            listeners.forEach { $0(value) }
        }
    }
    
    var calendar: Calendar {
        get {
            var cal = Calendar.current
            cal.timeZone = timeZone
            return cal
        }
    }
    
    var timeZone: TimeZone {
        get {
            // Some time zone that isn't UTC or mine (America/New_York).
            // I'm picking +UTC so epoch isn't slightly-awkwardly right before midnight.
            return TimeZone(identifier: "Europe/Athens")!
        }
    }
    
    private func enqueueAction(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
    
    private struct WorkItem: CustomStringConvertible {
        let id: UUID
        let fireAt: Date
        let block: () -> Void
        
        var description: String {
            "\(fireAt): \(id)"
        }
    }
    
    private struct NoopScheduledItem: ScheduledTask {
        func cancel() {
            // nothing
        }
    }

    private struct ManualScheduledItem: ScheduledTask {
        let parent: ManualTickScheduler
        let id: UUID
        
        func cancel() {
            parent.events.removeAll(where: {$0.id == id})
        }
    }
}


#endif
