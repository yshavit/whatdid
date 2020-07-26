import Cocoa

class SystemMenuItemManager: NSWindowController, NSWindowDelegate, NSMenuDelegate {
    
    private let POPUP_INTERVAL_MINUTES = 15
    private let POPUP_INTERVAL_JITTER_MINUTES = 3
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private var taskAdditionsPane : TaskAdditionViewController!
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
            show()
            AppDelegate.instance.onDeactivation {
                self.window?.close()
            }
            focus()
        }
    }
    
    func show() {
        if window?.isVisible ?? false {
            return
        }
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
        if !snoozing {
            schedulePopup()
        }
    }

    func schedulePopup() {
        let jitterMinutes = Int.random(in: -POPUP_INTERVAL_JITTER_MINUTES...POPUP_INTERVAL_JITTER_MINUTES)
        let minutes = POPUP_INTERVAL_MINUTES + jitterMinutes
        let when = DispatchWallTime.now() + .seconds(minutes * 60)
        DispatchQueue.main.asyncAfter(wallDeadline: when, execute: {
            if !self.snoozing {
                self.show()
            }
        })
    }
    
    func snooze(until date: Date) {
        snoozing = true
        window?.close()
        let wakeupTime = DispatchWallTime.now() + .seconds(Int(date.timeIntervalSinceNow))
        DispatchQueue.main.asyncAfter(wallDeadline: wakeupTime, execute: {
            self.snoozing = false
            self.show()
        })
    }
}
