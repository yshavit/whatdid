// whatdidTests?

import Cocoa
@testable import Whatdid

/// A Scheduler that doesn't depend on any system clock.
/// Instead, its tasks get enqueued until you manually run them via `runAllScheduled`. Useful for unit tests involving schedulers.
class DummyScheduler: Scheduler {
    private var tasks = [DummyScheduledTask]()
    let now = Date()
    let timeZone = TimeZone.current
    let calendar = Calendar.current
    
    func runAllScheduled() {
        for task in tasks {
            if !task.isCanceled && !task.hasRun {
                task.hasRun = true
                task.block()
            }
        }
    }
    
    func schedule(_ description: String, at: Date, _ block: @escaping () -> Void) -> ScheduledTask {
        return add(block)
    }
    
    private func add(_ block: @escaping () -> Void) -> ScheduledTask {
        let task = DummyScheduledTask(block)
        tasks.append(task)
        return task
    }
    
    class DummyScheduledTask: ScheduledTask {
        let block: () -> Void
        var hasRun = false
        var isCanceled = false
        
        init(_ block: @escaping () -> Void) {
            self.block = block
        }
        
        func cancel() {
            isCanceled = true
        }
    }
}
