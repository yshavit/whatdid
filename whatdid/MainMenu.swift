// whatdid?

import Cocoa

class MainMenu: NSWindowController, NSWindowDelegate, NSMenuDelegate {
    
    private let POPUP_INTERVAL_MINUTES = 10
    private let POPUP_INTERVAL_JITTER_MINUTES = 2
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var taskAdditionsPane : TaskAdditionViewController!
    private var windowContents = WindowContents.scheduledPtn
    private var shouldSchedulePopupOnClose = false
    private var snoozing = false
    
    enum WindowContents {
        /// The PTN window, when it pops up automatically
        case scheduledPtn
        /// The PTN window, when the user pops it up manually
        case manualPtn
        /// The end-of-day report
        case dailyEnd
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .floating
        taskAdditionsPane = TaskAdditionViewController()
        taskAdditionsPane.closeAction = {
            DispatchQueue.main.async {
                self.window?.close()
            }
        }
        window?.contentViewController = taskAdditionsPane
        window?.delegate = self
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.isMovable = false
        
        statusItem.button?.title = "✐"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemPress)
    }
    
    @objc private func handleStatusItemPress() {
        if window?.isVisible ?? false {
            window?.close()
        } else {
            let showWhat = NSEvent.modifierFlags.contains(.option)
                ? WindowContents.dailyEnd
                : WindowContents.manualPtn
            show(showWhat)
            AppDelegate.instance.onDeactivation {
                self.window?.close()
            }
            focus()
        }
    }
    
    func show(_ contents: WindowContents) {
        // Always schedule on close if this request was for a scheduled popup, even if the window is already open.
        // Otherwise, the thread of scheduled popups would die.
        if contents == .scheduledPtn {
            shouldSchedulePopupOnClose = true
        }
        if window?.isVisible ?? false {
            return
        }
        switch (contents) {
        case .dailyEnd:
            window?.contentViewController = DayEndReportController()
        case .manualPtn, .scheduledPtn:
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
        DispatchQueue.main.async {
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
        if shouldSchedulePopupOnClose && !snoozing { // If we're snoozing, the snooze scheduled the next popup
            schedulePopup()
        }
        shouldSchedulePopupOnClose = false
    }

    func schedulePopup() {
        let jitterMinutes = Int.random(in: -POPUP_INTERVAL_JITTER_MINUTES...POPUP_INTERVAL_JITTER_MINUTES)
        let minutes = POPUP_INTERVAL_MINUTES + jitterMinutes
        NSLog("Scheduling a popup in %d minutes", minutes)
        let when = DispatchWallTime.now() + .seconds(minutes * 60)
        DispatchQueue.main.asyncAfter(wallDeadline: when, execute: {
            if self.snoozing {
                NSLog("Ignoring a popup request due to snooze.")
            } else {
                NSLog("Showing a scheduled popup.")
                self.show(.scheduledPtn)
            }
        })
    }
    
    func snooze(until date: Date) {
        NSLog("Snoozing until %@", AppDelegate.DEBUG_DATE_FORMATTER.string(from: date))
        snoozing = true
        window?.close()
        let wakeupTime = DispatchWallTime.now() + .seconds(Int(date.timeIntervalSinceNow))
        DispatchQueue.main.asyncAfter(wallDeadline: wakeupTime, execute: {
            self.snoozing = false
            self.show(.scheduledPtn)
        })
    }
}
