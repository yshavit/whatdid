// whatdid?

import Cocoa

class SystemClockScheduler: Scheduler {
    static let TOLERANCE_SECONDS : TimeInterval = 60
    private var pendingTasks = [UUID: SystemScheduledTask]()
    
    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWakeup(_:)), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    var now: Date {
        return Date()
    }
    
    var timeZone: TimeZone {
        return TimeZone.autoupdatingCurrent
    }
    
    func schedule(_ description: String, at date: Date, _ block: @escaping () -> Void) -> ScheduledTask {
        let task = SystemScheduledTask(description: description, at: date, block: block, parent: self)
        pendingTasks[task.uuid] = task
        task.reschedule()
        return task
    }
    
    @objc private func handleWakeup(_ notification: Notification) {
        wdlog(.debug, "Rescheduling %d task(s)", pendingTasks.count)
        pendingTasks.values.forEach {$0.reschedule()}
    }
    
    fileprivate func remove(_ task: SystemScheduledTask) {
        pendingTasks.removeValue(forKey: task.uuid)
    }
    
    fileprivate func isTaskStillActive(_ task: SystemScheduledTask) -> Bool {
        return pendingTasks.keys.contains(task.uuid)
    }
    
    var approximatePendingTasksCount: Int {
        return pendingTasks.count
    }
    
    fileprivate class SystemScheduledTask: ScheduledTask {
        fileprivate let uuid: UUID
        private let description: String
        private let deadline: Date
        private let parent: SystemClockScheduler
        private var block: (() -> Void)!
        private var workItem: DispatchWorkItem?
        
        init(description: String, at date: Date, block: @escaping () -> Void, parent: SystemClockScheduler) {
            self.description = description
            self.deadline = date
            self.block = block
            self.parent = parent
            self.uuid = UUID()
        }
        
        func cancel() {
            cancelWorkItem()
            completeSelf()
        }
        
        func reschedule() {
            cancelWorkItem()
            let timeLeft = deadline.timeIntervalSinceNow
            if timeLeft <= 0 {
                wdlog(.debug, "Running %{public}@ immediately", description)
                DispatchQueue.main.async(execute: runBlock)
            } else {
                wdlog(.debug, "Scheduling %{public}@ at %{public}@", description, deadline as NSDate)
                workItem = DispatchWorkItem(qos: .utility, block: runBlock)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + timeLeft, execute: workItem!)
            }
        }
        
        func runBlock() {
            guard parent.isTaskStillActive(self) else {
                return
            }
            block()
            completeSelf()
        }
        
        private func cancelWorkItem() {
            if let active = workItem {
                active.cancel()
            }
            workItem = nil
        }
        
        private func completeSelf() {
            block = nil
            parent.remove(self)
        }
    }
}

extension DispatchWorkItem: ScheduledTask {
    // ScheduledTask.cancel() is already defined
}
