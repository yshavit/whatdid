// whatdid?

import Cocoa

class MainMenu: NSWindowController, NSWindowDelegate, NSMenuDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var taskAdditionsPane : PtnViewController!
    private var windowContents = WindowContents.ptn
    private var opener : OpenCloseHelper<WindowContents>!
    private var cancelClose = false
    private var snoozed: (until: Date, unsnoozeTask: ScheduledTask)?
    private var scheduledTasks = [WindowContents: ScheduledTask]()
    
    enum WindowContents: Int, Comparable {
        /// The Project/Task/Notes window
        case ptn
        /// The end-of-day report
        case dailyEnd
        
        static func < (lhs: MainMenu.WindowContents, rhs: MainMenu.WindowContents) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    func open(_ item: WindowContents, reason: OpenReason) {
        opener.open(item, reason: reason)
    }
    
    override func close() {
        if windowShouldClose(window!) {
            super.close()
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancelClose = false
        opener.didClose()
        return !cancelClose
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .floating
        taskAdditionsPane = PtnViewController()
        taskAdditionsPane.closeAction = {
            DispatchQueue.main.async {
                self.close()
            }
        }
        window?.contentViewController = taskAdditionsPane
        window?.delegate = self
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.isMovable = false
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        
        statusItem.button?.title = "✐"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemPress)
        
        opener = OpenCloseHelper<WindowContents>(
            onOpen: {ctx in
                NSLog("MainMenu handling \(ctx.reason) open request for \(ctx.item)")
                self.doOpen(ctx.item, scheduler: ctx.scheduler)
                if ctx.reason == .manual {
                    self.focus()
                }
            },
            onSchedule: self.schedule)
        taskAdditionsPane.forceReschedule = opener.forceRescheduleOnClose
    }
    
    @objc private func handleStatusItemPress() {
        if window?.isVisible ?? false {
            close()
        } else {
            let showWhat = NSEvent.modifierFlags.contains(.option)
                ? WindowContents.dailyEnd
                : WindowContents.ptn
            opener.open(showWhat, reason: .manual)
        }
    }
    
    private func doOpen(_ contents: WindowContents, scheduler newScheduler: Scheduler) {
        switch (contents) {
        case .dailyEnd:
            let controller = DayEndReportController()
            window?.contentViewController = controller
            controller.prepareForViewing()
            controller.scheduler = newScheduler
            window?.title = "Here's what you've been doing"
        case .ptn:
            taskAdditionsPane.scheduler = newScheduler
            window?.contentViewController = taskAdditionsPane
            window?.title = "What are you working on?"
        }
        
        window!.setContentSize(window!.contentViewController!.view.fittingSize)
        if let mainFrame = statusItem.button?.window?.screen?.visibleFrame, let button = statusItem.button {
            var pos = NSPoint(
                x: button.window?.frame.minX ?? .zero,
                y: mainFrame.origin.y + mainFrame.height)
            if let myWindow = window {
                if let screen = myWindow.screen {
                    let tooFarLeftBy = (pos.x + myWindow.frame.width) - screen.frame.width
                    if tooFarLeftBy > 0 {
                        pos.x -= tooFarLeftBy
                    }
                }
                window?.setFrameTopLeftPoint(pos)
            }
        }
        if window?.isVisible ?? false {
            contentViewController?.viewWillAppear()
            cancelClose = true
        } else {
            showWindow(self)
        }
        RunLoop.current.perform {
            self.statusItem.button?.isHighlighted = true
        }
    }
    
    func focus() {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        if !(window?.isVisible ?? false) {
            opener.open(.ptn, reason: .manual)
        }
        window?.makeKeyAndOrderFront(self)
        if window?.contentView == taskAdditionsPane.view {
            taskAdditionsPane.grabFocus()
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        if let activeWindow = window {
            for sheet in activeWindow.sheets {
                activeWindow.endSheet(sheet, returnCode: .cancel)
            }
        }
        NSApp.hide(self)
        statusItem.button?.isHighlighted = false
    }

    func schedule(_ contents: WindowContents) {
        let newTask: ScheduledTask
        switch contents {
        case .ptn:
            let jitter = Prefs.ptnFrequencyJitterMinutes
            let jitterMinutes = Int.random(in: -jitter...jitter)
            let minutes = Double(Prefs.ptnFrequencyMinutes + jitterMinutes)
            newTask = DefaultScheduler.instance.schedule(String(describing: contents), after: minutes * 60.0) {
                self.opener.open(.ptn, reason: .scheduled)
            }
        case .dailyEnd:
            let scheduleEndOfDay = Prefs.dailyReportTime.map {hh, mm in TimeUtil.dateForTime(.next, hh: hh, mm: mm) }
            newTask = DefaultScheduler.instance.schedule("EOD summary", at: scheduleEndOfDay) {
                self.opener.open(.dailyEnd, reason: .scheduled)
            }
        }
        if let oldTask = scheduledTasks.updateValue(newTask, forKey: contents) {
            NSLog("Replaced previously scheduled open for \(contents)")
            oldTask.cancel()
        }
    }
    
    func snooze(until date: Date) {
        if let (until: _, unsnoozeTask: task) = snoozed {
            task.cancel()
        }
        NSLog("Snoozing until %@", AppDelegate.DEBUG_DATE_FORMATTER.string(from: date))
        opener.snooze()
        close()
        let task = DefaultScheduler.instance.schedule("unsnooze", after: date.timeIntervalSinceWhatdidNow, self.unSnooze)
        snoozed = (until: date, unsnoozeTask: task)
    }
    
    func unSnooze() {
        if let (until: _, unsnoozeTask: task) = snoozed {
            task.cancel()
            snoozed = nil
            opener.unSnooze()
        }
    }
    
    var snoozedUntil: Date? {
        snoozed?.until
    }
}
