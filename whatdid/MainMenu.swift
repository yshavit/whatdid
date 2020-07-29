// whatdid?

import Cocoa

class MainMenu: NSWindowController, NSWindowDelegate, NSMenuDelegate {
    
    private let POPUP_INTERVAL_MINUTES = 15
    private let POPUP_INTERVAL_JITTER_MINUTES = 3
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var taskAdditionsPane : TaskAdditionViewController!
    private var schedulePopupOnClose = false
    private var snoozing = false

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
            if NSEvent.modifierFlags.contains(.option) {
                window?.contentViewController = DayEndReportController()
            }
            show(schedulePopupOnClose: false)
            AppDelegate.instance.onDeactivation {
                self.window?.close()
            }
            focus()
        }
    }
    
    func show(schedulePopupOnClose: Bool) {
        if window?.isVisible ?? false {
            // If this show was from a scheduled popup, mark the currently opened window as
            // a scheduled popup (even if wasn't originally). Otherwise, the thread of
            // scheduled popups would die.
            if schedulePopupOnClose {
                self.schedulePopupOnClose = true
            }
            return
        }
        self.schedulePopupOnClose = schedulePopupOnClose
        if let mainFrame = NSScreen.main?.visibleFrame, let button = statusItem.button {
            let buttonBoundsAbsolute = button.window?.convertToScreen(button.bounds)
            let pos = NSPoint(
                x: buttonBoundsAbsolute?.minX ?? .zero,
                y: mainFrame.origin.y + mainFrame.height)
            window?.setFrameTopLeftPoint(pos)
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
            taskAdditionsPane.grabFocus()
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.hide(self)
        statusItem.button?.isHighlighted = false
        window?.contentViewController = taskAdditionsPane
        if schedulePopupOnClose && !snoozing {
            schedulePopup()
        }
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
                self.show(schedulePopupOnClose: true)
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
            self.show(schedulePopupOnClose: true)
        })
    }
}
