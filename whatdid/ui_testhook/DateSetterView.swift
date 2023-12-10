#if UI_TEST
import Cocoa

class DateSetterView: WdView, NSTextFieldDelegate {
    private var setter: NSTextField! // TODO rename
    private var printUtc: NSTextField!
    private var printLocal: NSTextField!
    var onDateChange: (Date) -> Void = {_ in }
    var deferHandler: DateSetterDeferHandler?
    
    let scheduler: ManualTickScheduler = DefaultScheduler.instance

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func wdViewInit() {
        setter = NSTextField(string: "0")
        setter.isEditable = true
        setter.setAccessibilityLabel("uitestwindowclock")
        setter.delegate = self // TODO is this right?
        
        printUtc = NSTextField(labelWithString: "")
        printUtc.setAccessibilityLabel("mockclock_status")
        printLocal = NSTextField(labelWithString: "")
        
        scheduler.addListener(self.updateDateDisplays(to:))
        
        let stack = NSStackView(orientation: .vertical,
                                setter,
                                printUtc,
                                printLocal
        )
        stack.alignment = .leading
        addSubview(stack)
        anchorAllSides(to: stack)
    }
    
    override func becomeFirstResponder() -> Bool {
        return setter.becomeFirstResponder()
    }
    
    override var acceptsFirstResponder: Bool {
        return setter.acceptsFirstResponder
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false {
            let origValue = setter.stringValue
            setter.isEnabled = false
            var secondsRemaining = 3
            Timer.scheduledTimer(withTimeInterval: TimeInterval(1), repeats: true, block: {timer in
                if secondsRemaining == 0 {
                    timer.invalidate()
                    self.setter.isEnabled = true
                    self.setter.stringValue = origValue
                    self.updateDate()
                } else {
                    self.setter.stringValue = "Setting in \(secondsRemaining)..."
                    secondsRemaining -= 1
                }
            }).fire()
        }
        if setter.isEnabled {
            updateDate()
        }
    }
    
    func updateDate() {
        if let date = date {
            updateDateDisplays(to: date)
            
            if let deferred = deferHandler?.deferIfNeeded() {
                AppDelegate.instance.whenNotActive {
                    deferred()
                    self.scheduler.now = date
                }
            } else {
                scheduler.now = date
            }
        } else {
            printUtc.stringValue = "ERROR"
            printLocal.stringValue = "ERROR"
        }
    }
    
    func updateDateDisplays(to date: Date) {
        setter.stringValue = "\(Int(date.timeIntervalSince1970))"
        
        let timeFormatter = ISO8601DateFormatter()
        timeFormatter.timeZone = TimeZone.utc
        printUtc.stringValue = timeFormatter.string(from: date)
        
        timeFormatter.timeZone = DefaultScheduler.instance.timeZone
        printLocal.stringValue = timeFormatter.string(from: date)
    }
    
    var date: Date? {
        if let dateAsInt = Int(setter.stringValue) {
            return Date(timeIntervalSince1970: Double(dateAsInt))
        } else {
            return nil
        }
    }
}


protocol DateSetterDeferHandler {
    /// Starts a deferred action, and returns a func to be invoked on un-defer.
    func deferIfNeeded() -> DateSetterDeferredAction?
}

typealias DateSetterDeferredAction = () -> Void

#endif
