// whatdid?

import Cocoa

class DelegatingScheduler: Scheduler {
    private let delegate: Scheduler
    private var tasks = [UUID: ScheduledTask]()
    private var isOpen = true
    
    init(delegateTo delegate: Scheduler) {
        self.delegate = delegate
    }
    
    var now: Date {
        delegate.now
    }
    
    var timeZone: TimeZone {
        delegate.timeZone
    }
    
    /// The number of tasks currently being tracked by this scheduler. Intended for testing (to ensure there are no memory leaks).
    var tasksCount: Int {
        return tasks.count
    }
    
    @discardableResult func schedule(at: Date, _ block: @escaping () -> Void) -> ScheduledTask {
        guard isOpen else {
            NSLog("Ignoring task because DelegatingScheduler has been closed")
            return NoopTask()
        }
        let work = createTrackingBlock(block)
        work.tracks = delegate.schedule(at: at, work.run)
        return work
    }
    
    @discardableResult func schedule(after: TimeInterval, _ block: @escaping () -> Void) -> ScheduledTask {
        guard isOpen else {
            NSLog("Ignoring task because DelegatingScheduler has been closed")
            return NoopTask()
        }
        let work = createTrackingBlock(block)
        work.tracks = delegate.schedule(after: after, work.run)
        return work
    }
    
    func close() {
        for id in tasks.keys {
            let task = tasks.removeValue(forKey: id)
            task?.cancel()
        }
        isOpen = false
    }
    
    private func createTrackingBlock(_ block: @escaping () -> Void) -> Tracker {
        let tracker = Tracker(parent: self, task: block)
        tasks[tracker.id] = tracker
        return tracker
    }
    
    private struct NoopTask: ScheduledTask {
        func cancel() {
            // nothing
        }
    }
    
    private class Tracker: ScheduledTask {
        let id = UUID()
        let parent: DelegatingScheduler
        let task: () -> Void
        var tracks: ScheduledTask? = nil
        
        init(parent: DelegatingScheduler, task: @escaping () -> Void) {
            self.parent = parent
            self.task = task
        }
        
        func run() {
            parent.tasks.removeValue(forKey: id)
            task()
        }
        
        func cancel() {
            parent.tasks.removeValue(forKey: id)
            tracks?.cancel()
        }
    }
}
