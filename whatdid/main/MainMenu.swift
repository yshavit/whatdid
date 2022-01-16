// whatdid?

import Cocoa

class MainMenu: NSWindowController, NSWindowDelegate, NSMenuDelegate, PtnViewDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var taskAdditionsPane : PtnViewController!
    private var windowContents = WindowContents.ptn
    private var opener : OpenCloseHelper<WindowContents>!
    private var cancelClose = false
    private var snoozed: (until: Date, unsnoozeTask: ScheduledTask)?
    private var scheduledTasks = [WindowContents: ScheduledTask]()
    
    #if UI_TEST
    func reset() {
        // Keep asking whether we should close, until the answer comes back yes. What this amounts to
        // is that we'll flush any pending scheduled opens. There can only be as many of these as WindowContents values,
        // so only loop that many times; this serves as a backstop against an infinite loop, in case there's a bug elsewhere
        // in the opener logic.
        unSnooze()
        if let window = window {
            for sheet in window.sheets {
                window.endSheet(sheet, returnCode: .cancel)
            }
            for _ in WindowContents.allCases {
                _ = windowShouldClose(window)
            }
            window.contentViewController?.closeWindowAsync()
        }
        // Cancel any outstanding scheduled tasks. These shouldn't actually matter, because they'll be things like updating
        // the "it's been X minutes" text, or the snooze options; but may as well.
        for task in scheduledTasks.values {
            task.cancel()
        }
        // Lastly, re-initialize the PTN itself.
        taskAdditionsPane = PtnViewController()
        taskAdditionsPane.hooks = self
    }
    #endif
    
    enum WindowContents: Int, Comparable, CaseIterable {
        /// The Project/Task/Notes window
        case ptn
        /// The end-of-day report
        case dailyEnd
        /// Start of the day
        case dayStart
        
        static func < (lhs: MainMenu.WindowContents, rhs: MainMenu.WindowContents) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        var description: String {
            return String(describing: self)
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
            wdlog(.error, "Took too long to find status item's screen. Giving up on showing initial content.")
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
            wdlog(.debug, "closing window")
            super.close()
        } else {
            wdlog(.debug, "canceling window close")
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let window = window {
            // Get all of the sheets (in top-to-bottom order), and then the current window.
            // That means that whatever the user sees has first crack at refusing the close.
            let allWindows = window.sheets + [window]
            let allCloseConfirmers = allWindows.compactMap({$0.contentViewController as? CloseConfirmer})
            for closeConfirmer in allCloseConfirmers {
                if !closeConfirmer.requestClose(on: sender) {
                    return false
                }
            }
        }
        cancelClose = false
        opener.didClose()
        return !cancelClose
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .floating
        taskAdditionsPane = PtnViewController()
        
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
                AppDelegate.instance.incrementWindowCounter()
                wdlog(.debug, "MainMenu handling %{public}@ open request for %{public}@", ctx.reason.description, ctx.item.description)
                self.doOpen(ctx.item, scheduler: ctx.scheduler)
                if ctx.reason == .manual {
                    self.focus()
                }
            },
            onSchedule: self.schedule)
        taskAdditionsPane.hooks = self
    }
    
    var isOpen: Bool {
        return window?.isVisible ?? false
    }
    
    @objc private func handleStatusItemPress() {
        if isOpen {
            close()
        } else {
            let showWhat = NSEvent.modifierFlags.contains(.option)
                ? WindowContents.dailyEnd
                : WindowContents.ptn
            opener.open(showWhat, reason: .manual)
        }
    }
    
    private func doOpen(_ contents: WindowContents, scheduler newScheduler: Scheduler) {
        guard let window = window else {
            wdlog(.error, "no window to open for MainMenu::doOpen")
            return
        }
        switch (contents) {
        case .dailyEnd:
            let controller = DayEndReportController()
            window.contentViewController = controller
            controller.prepareForViewing()
            controller.scheduler = newScheduler
            window.title = "Here's what you've been doing"
        case .ptn:
            taskAdditionsPane.scheduler = newScheduler
            window.contentViewController = taskAdditionsPane
            window.title = "What are you working on?"
        case .dayStart:
            let controller = DayStartController()
            controller.scheduler = newScheduler
            window.contentViewController = controller
            window.title = "Start the day with some goals"
        }
        
        window.setContentSize(window.contentViewController!.view.fittingSize)
        if let button = statusItem.button, let buttonWindow = button.window, let buttonScreen = buttonWindow.screen {
            let mouseLoc = NSEvent.mouseLocation
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
            
            // Adjust the position if it would put the window off the edge of the screen
            let tooFarLeftBy = (pos.x + window.frame.width) - mouseScreen.frame.width
            if tooFarLeftBy > 0 {
                pos.x -= tooFarLeftBy
            }
            window.setFrameTopLeftPoint(pos)
        }
        if window.isVisible {
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
        wdlog(.debug, "window will close")
        if let activeWindow = window {
            for sheet in activeWindow.sheets {
                activeWindow.endSheet(sheet, returnCode: .cancel)
            }
        }
        DispatchQueue.main.async {
            wdlog(.debug, "unhighlighting icon and closing main window")
            self.statusItem.button?.isHighlighted = false
            AppDelegate.instance.decrementWindowCounter()
        }
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
            wdlog(.debug, "Replaced previously scheduled open for %{public}@", contents.description)
            oldTask.cancel()
        }
    }
    
    func forceReschedule() {
        opener.forceRescheduleOnClose()
    }
    
    func snooze(until date: Date) {
        if let (until: _, unsnoozeTask: task) = snoozed {
            task.cancel()
        }
        wdlog(.debug, "Snoozing until %{public}@", AppDelegate.DEBUG_DATE_FORMATTER.string(from: date))
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
