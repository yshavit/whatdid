// whatdid?

import Cocoa

class OpenCloseHelper<T: Hashable & Comparable> {
    
    private let opener: (T, OpenReason) -> Void
    private let scheduler: (T) -> Void
    
    var openItem: T? = nil
    private var pendingOpens = [T: OpenReason]()
    private var rescheduleOnClose = false
    private var isSnoozed = false
    
    init(onOpen: @escaping (T, OpenReason) -> Void, onSchedule: @escaping (T) -> Void) {
        self.opener = onOpen
        self.scheduler = onSchedule
    }
    
    func open(_ item: T, reason: OpenReason) {
        let requestDesc = "request for \(reason) open of \(item) at \(DefaultScheduler.instance.now.utcTimestamp)"
        if openItem == nil {
            if (reason == .scheduled) && isSnoozed {
                pendingOpens[item] = reason
                NSLog("Deferring \(requestDesc) because of snooze")
            } else {
                openItem = item
                NSLog("Acting on \(requestDesc)")
                opener(item, reason)
                rescheduleOnClose = reason == .scheduled
            }
        } else if reason == .scheduled {
            if openItem == item {
                rescheduleOnClose = true
                NSLog("Ignoring \(requestDesc) because it is already open. Will reschedule it on close.")
            } else {
                pendingOpens[item] = reason
                NSLog("Deferring \(requestDesc) because another item is already open")
            }
        } else {
            // If we're already open, we shouldn't be able to get a manual open; the UI should prevent that.
            // We should check that condition (as we just did) to be safe and to let us write comprehensive unit tests,
            // but really it's just a weird corner case.
            NSLog("WARN Tried to open \(item) manually while \(openItem!) was already open")
        }
    }
    
    func snooze() {
        isSnoozed = true
    }
    
    func unSnooze() {
        isSnoozed = false
        pullFromPending()
    }

    func didClose() {
        guard openItem != nil else {
            return
        }
        if rescheduleOnClose {
            let item = openItem!
            rescheduleOnClose = false
            openItem = nil
            // Schedule even if we're snoozed; if we're still snoozed when the schedule hits, then
            // it'll enqueue itself
            NSLog("OpenCloseHelper: scheduling the next \(item)")
            scheduler(item)
        }
        openItem = nil
        if !isSnoozed {
            pullFromPending()
        }
    }
    
    private func pullFromPending() {
        if let deferredOpenKey = pendingOpens.keys.sorted().first {
            rescheduleOnClose = pendingOpens.removeValue(forKey: deferredOpenKey)! == .scheduled
            NSLog("OpenCloseHelper: opening deferred \(deferredOpenKey), with next rescheduleOnClose = \(rescheduleOnClose)")
            openItem = deferredOpenKey
            opener(deferredOpenKey, .scheduled)
        }
    }
}
