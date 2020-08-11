// whatdid?

import Cocoa

class MainMenu: NSWindowController, NSWindowDelegate, NSMenuDelegate {
    
    private let POPUP_INTERVAL_MINUTES = 10
    private let POPUP_INTERVAL_JITTER_MINUTES = 2
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var taskAdditionsPane : PtnViewController!
    private var windowContents = WindowContents.ptn
    private var snoozing = false
    private var opener : OpenCloseHelper<WindowContents>!
    
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

    override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .floating
        taskAdditionsPane = PtnViewController()
        taskAdditionsPane.closeAction = {
            DispatchQueue.main.async {
                self.window?.close()
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
        

        AppDelegate.instance.onDeactivation {
            self.window?.close()
        }
        
        opener = OpenCloseHelper<WindowContents>(
            onOpen: {contents in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
                    self.open(contents)
                }
            },
            onSchedule: self.schedule)
    }
    
    @objc private func handleStatusItemPress() {
        if window?.isVisible ?? false {
            window?.close()
        } else {
            let showWhat = NSEvent.modifierFlags.contains(.option)
                ? WindowContents.dailyEnd
                : WindowContents.ptn
            opener.open(showWhat, reason: .manual)
            focus()
        }
    }
    
    private func open(_ contents: WindowContents) {
        switch (contents) {
        case .dailyEnd:
            window?.contentViewController = DayEndReportController()
        case .ptn:
            window?.contentViewController = taskAdditionsPane
        }
        
        window?.layoutIfNeeded()
        if let mainFrame = NSScreen.main?.visibleFrame, let button = statusItem.button {
            let buttonBoundsAbsolute = button.window?.convertToScreen(button.bounds)
            var pos = NSPoint(
                x: buttonBoundsAbsolute?.minX ?? .zero,
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
        showWindow(self)
        RunLoop.current.perform {
            self.statusItem.button?.isHighlighted = true
        }
    }
    
    func focus() {
        if window?.isVisible ?? false {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            window?.makeKeyAndOrderFront(self)
            if window?.contentView == taskAdditionsPane.view {
                taskAdditionsPane.grabFocus()
            }
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.hide(self)
        statusItem.button?.isHighlighted = false
        opener.didClose()
    }
    
    @objc private func showDailyReport() {
        open(.dailyEnd)
    }

    func schedule(_ contents: WindowContents) {
        switch contents {
        case .ptn:
            let jitterMinutes = Int.random(in: -POPUP_INTERVAL_JITTER_MINUTES...POPUP_INTERVAL_JITTER_MINUTES)
            let minutes = POPUP_INTERVAL_MINUTES + jitterMinutes
            NSLog("Scheduling a popup in %d minutes", minutes)
            let when = DispatchWallTime.now() + .seconds(minutes * 60)
            DispatchQueue.main.asyncAfter(wallDeadline: when, execute: {
                if self.snoozing {
                    NSLog("Ignoring a popup request due to snooze.")
                } else {
                    NSLog("Showing a scheduled popup.")
                    self.opener.open(.ptn, reason: .scheduled)
                }
            })
        case .dailyEnd:
            AppDelegate.instance.scheduleEndOfDaySummary()
//            self.scheduleEndOfDaySummary()
//            RunLoop.current.perform(inModes: [RunLoop.Mode.common], block: { self.open(.dailyEnd) })
//            perform(#selector(showDailyReport), with: nil, afterDelay: TimeInterval.zero, inModes: [RunLoop.Mode.common])
            
        }
    }
    
    func snooze(until date: Date) {
        NSLog("Snooze disabled")
//        NSLog("Snoozing until %@", AppDelegate.DEBUG_DATE_FORMATTER.string(from: date))
//        snoozing = true
//        window?.close()
//        let wakeupTime = DispatchWallTime.now() + .seconds(Int(date.timeIntervalSinceNow))
//        DispatchQueue.main.asyncAfter(wallDeadline: wakeupTime, execute: {
//            self.snoozing = false
//            self.open(.ptn)
//        })
    }
}
