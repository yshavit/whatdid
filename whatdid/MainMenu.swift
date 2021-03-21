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
        /// Start of the day
        case dayStart
        
        static func < (lhs: MainMenu.WindowContents, rhs: MainMenu.WindowContents) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    func open(_ item: WindowContents, reason: OpenReason) {
        opener.open(item, reason: reason)
    }
    
    func whenPtnIsReady(_ block: @escaping (PtnViewController) -> Void) {
        whenPtnIsReady(block, remainingAttempts: 1500)
    }
    
    private func whenPtnIsReady(_ block: @escaping (PtnViewController) -> Void, remainingAttempts: Int) {
        // It takes a few millis for the status item to get connected to the screen
        if remainingAttempts <= 0 {
            NSLog("Took too long to find status item's screen. Giving up on showing initial content.")
        } else if statusItem.button?.window?.screen == nil {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(1)) {
                self.whenPtnIsReady(block, remainingAttempts: remainingAttempts - 1)
            }
        } else {
            if let ptn = taskAdditionsPane {
                block(ptn)
            }
        }
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
    
    
    private func contentViewCloseAction() {
        DispatchQueue.main.async {
            self.close()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .floating
        taskAdditionsPane = PtnViewController()
        taskAdditionsPane.closeAction = contentViewCloseAction
        
        if let window = window {
            window.contentViewController = taskAdditionsPane
            window.delegate = self
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.isMovable = false
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
        if let button = statusItem.button {
            button.title = "✐"
            button.target = self
            button.action = #selector(handleStatusItemPress)
            button.image = NSImage(named: "MenuIcon")
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyUpOrDown
        }
        
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
        case .dayStart:
            let controller = DayStartController(onClose: contentViewCloseAction)
            controller.scheduler = newScheduler
            window?.contentViewController = controller
            window?.title = "Start the day with some goals"
        }
        
        window!.setContentSize(window!.contentViewController!.view.fittingSize)
        if let button = statusItem.button, let buttonWindow = button.window, let buttonScreen = buttonWindow.screen, let windowToOpen = window {
            NSLog("Available screens:")
            let mouseLoc = NSEvent.mouseLocation
            for screen in NSScreen.screens {
                var bullet = "-"
                var suffix = ""
                if screen.frame.contains(mouseLoc) {
                    bullet = "*"
                    suffix = " <-- contains mouse"
                }
                NSLog("    \(bullet) \(screen.frame)\(suffix)")
            }
            NSLog("    - mouse is at \(mouseLoc)")
            NSLog("    - button.window: \(buttonWindow.frame)")
            
            let buttonRectInWindow = button.convert(button.bounds, to: nil)
            let buttonRectInScreen = buttonWindow.convertToScreen(buttonRectInWindow)
            let buttonMarginFromScreenEdge = buttonScreen.frame.maxX - buttonRectInScreen.origin.x
            let mouseScreen = NSScreen.screens.first {screen in
                // screen.frame.contains can be off by 1, so enlarge it just slightly.
                // (This happens especially when the mouse is as high up as it can go.)
                screen.frame.insetBy(dx: -2, dy: -2).contains(mouseLoc)
            } ?? buttonScreen // failsafe, but shouldn't ever be needed
            let xPosInMouseScreen = mouseScreen.frame.maxX - buttonMarginFromScreenEdge
            var pos = NSPoint(x: xPosInMouseScreen, y: mouseScreen.visibleFrame.maxY)
            
            NSLog("    - button.window.screen: \(buttonScreen.frame)")
            NSLog("    - mouseScreen: \(mouseScreen.frame)")
            let tooFarLeftBy = (pos.x + windowToOpen.frame.width) - mouseScreen.frame.width
            if tooFarLeftBy > 0 {
                pos.x -= tooFarLeftBy
            }
            windowToOpen.setFrameTopLeftPoint(pos)
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
        case .dayStart:
            let startOfDay = Prefs.dayStartTime.map {hh, mm in TimeUtil.dateForTime(.next, hh: hh, mm: mm) }
            newTask = DefaultScheduler.instance.schedule("Day start", at: startOfDay) {
                self.opener.open(.dayStart, reason: .scheduled)
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
