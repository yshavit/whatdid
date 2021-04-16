// whatdid?

import Cocoa

class OpenCloseHelper<T: Hashable & Comparable> {
    
    private let opener: (OpenContext) -> Void
    private let scheduler: (T) -> Void
    private let underlyingScheduler: Scheduler
    
    var openItem: T? = nil
    private var pendingOpens = [T: OpenReason]()
    private var rescheduleOnClose = false
    private var isSnoozed = false
    private var delegatingScheduler : DelegatingScheduler?
    
    init(onOpen: @escaping (OpenContext) -> Void, onSchedule: @escaping (T) -> Void, using: Scheduler = DefaultScheduler.instance) {
        self.opener = onOpen
        self.scheduler = onSchedule
        self.underlyingScheduler = using
    }
    
    func open(_ item: T, reason: OpenReason) {
        let requestDesc = "request for \(reason) open of \(item) at \(DefaultScheduler.instance.now.utcTimestamp)"
        if openItem == nil {
            if (reason == .scheduled) && isSnoozed {
                pendingOpens[item] = reason
                wdlog(.debug, "Deferring %@ because of snooze", requestDesc)
            } else {
                wdlog(.debug, "Acting on %@", requestDesc)
                doOpen(item, reason)
                rescheduleOnClose = reason == .scheduled
            }
        } else if reason == .scheduled {
            if openItem == item {
                rescheduleOnClose = true
                wdlog(.debug, "Ignoring %@ because it is already open. Will reschedule it on close.", requestDesc)
            } else {
                pendingOpens[item] = reason
                wdlog(.debug, "Deferring %@ because another item is already open", requestDesc)
            }
        } else {
            // If we're already open, we shouldn't be able to get a manual open; the UI should prevent that.
            // We should check that condition (as we just did) to be safe and to let us write comprehensive unit tests,
            // but really it's just a weird corner case.
            wdlog(.warn, "Tried to open %@ manually while %@ was already open", s(item), s(openItem!))
        }
    }
    
    func forceRescheduleOnClose() {
        rescheduleOnClose = true
    }
    
    func snooze() {
        isSnoozed = true
    }
    
    func unSnooze() {
        isSnoozed = false
        pullFromPending()
    }

    func didClose() {
        delegatingScheduler?.close()
        delegatingScheduler = nil
        guard let item = openItem else {
            return
        }
        openItem = nil
        if rescheduleOnClose {
            rescheduleOnClose = false
            // Schedule even if we're snoozed; if we're still snoozed when the schedule hits, then
            // it'll enqueue itself
            wdlog(.debug, "OpenCloseHelper: scheduling the next ", s(item))
            scheduler(item)
        }
        if !isSnoozed {
            pullFromPending()
        }
    }
    
    private func doOpen(_ item: T, _ reason: OpenReason) {
        openItem = item
        if delegatingScheduler != nil {
            wdlog(.warn, "found non-nil DelegatingScheduler in OpenCloseHelper. Closing it.")
            delegatingScheduler?.close()
        }
        delegatingScheduler = DelegatingScheduler(delegateTo: underlyingScheduler)
        opener(OpenContext(item: item, reason: reason, scheduler: delegatingScheduler!))
    }
    
    private func pullFromPending() {
        if let deferredOpenKey = pendingOpens.keys.sorted().first {
            rescheduleOnClose = pendingOpens.removeValue(forKey: deferredOpenKey)! == .scheduled
            wdlog(.debug, "OpenCloseHelper: opening deferred %@, with next rescheduleOnClose = %d", s(deferredOpenKey), rescheduleOnClose)
            openItem = deferredOpenKey
            doOpen(deferredOpenKey, .scheduled)
        }
    }
    
    class OpenContext {
        let item: T
        let reason: OpenReason
        let scheduler: Scheduler
        
        init(item: T, reason: OpenReason, scheduler: Scheduler) {
            self.item = item
            self.reason = reason
            self.scheduler = scheduler
        }
    }
    
    private func s(_ item: T) -> String {
        return String(describing: item)
    }
}
