#if UI_TEST
import Cocoa

class DateSetterView: WdView, NSTextFieldDelegate {
    private var epochText: NSTextField!
    private var printUtc: NSTextField!
    private var printLocal: NSTextField!
    private var printRelative: NSTextField!
    private var relativeSteppers = [TimeUnit: StepperPair]()
    
    var onDateChange: (Date) -> Void = {_ in }
    var deferHandler: DateSetterDeferHandler?
    
    let scheduler: ManualTickScheduler = DefaultScheduler.instance
    
    private var subControls: [NSControl] {
        [epochText] + relativeSteppers.values.flatMap({p in [p.text, p.stepper]})
    }
    
    override func wdViewInit() {
        epochText = NSTextField(string: "0")
        epochText.isEditable = true
        epochText.setAccessibilityLabel("uitestwindowclock")
        epochText.delegate = self
        
        printUtc = NSTextField(labelWithString: "")
        printUtc.setAccessibilityLabel("mockclock_status")
        printLocal = NSTextField(labelWithString: "")
        
        let relativeViews = NSStackView()
        relativeViews.spacing = 0
        relativeViews.orientation = .horizontal
        
        let integerFormatter = NumberFormatter()
        integerFormatter.numberStyle = .none
        integerFormatter.minimum = NSNumber(value: 0)
        
        for unit in TimeUnit.allCases {
            let stepper = NSStepper()
            stepper.increment = 1
            stepper.controlSize = .small
            stepper.minValue = 0
            stepper.maxValue = Double.greatestFiniteMagnitude
            stepper.target = self
            stepper.action = #selector(self.stepperClicked(_:))
            
            let field = NSTextField(string: "0")
            field.controlSize = .mini
            field.font = field.font?.withSize(NSFont.smallSystemFontSize)
            field.widthAnchor.constraint(equalToConstant: 24).isActive = true
            field.formatter = integerFormatter
            field.delegate = self
            
            relativeSteppers[unit] = StepperPair(text: field, stepper: stepper)

            relativeViews.addArrangedSubview(field)
            relativeViews.addArrangedSubview(stepper)
            relativeViews.addArrangedSubview(NSTextField(labelWithString: "\(unit) "))
        }
        
        printRelative = NSTextField(labelWithString: "")
        
        scheduler.addListener(self.updateDateDisplays(to:))
        
        let stack = NSStackView(orientation: .vertical,
                                epochText,
                                printUtc,
                                printLocal,
                                relativeViews
        )
        stack.alignment = .leading
        addSubview(stack)
        anchorAllSides(to: stack)
    }
    
    override func becomeFirstResponder() -> Bool {
        return epochText.becomeFirstResponder()
    }
    
    override var acceptsFirstResponder: Bool {
        return epochText.acceptsFirstResponder
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let objTarget = obj.object as? NSControl else {
            return
        }
        
        if let (_, pair) = relativeSteppers.first(where: {(_, pair) in pair.text === objTarget}) {
            pair.stepper.integerValue = pair.text.integerValue
            updateSetterFromSteppers()
        }
        
        if NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false {
            let origValue = epochText.stringValue
            subControls.forEach({$0.isEnabled = false})
            var secondsRemaining = 3
            Timer.scheduledTimer(withTimeInterval: TimeInterval(1), repeats: true, block: {timer in
                if secondsRemaining == 0 {
                    timer.invalidate()
                    self.subControls.forEach({$0.isEnabled = true})
                    self.epochText.stringValue = origValue
                    self.updateDate()
                } else {
                    self.epochText.stringValue = "Setting in \(secondsRemaining)..."
                    secondsRemaining -= 1
                }
            }).fire()
        }
        if epochText.isEnabled {
            updateDate()
        }
    }
    
    func control(_ control: NSControl, didFailToFormatString string: String, errorDescription error: String?) -> Bool {
        // Called when the entered string cannot be formatted by the formatter. Reject it.
        return false
    }
    
    @objc func stepperClicked(_ clickedOn: NSStepper) {
        guard let (_, pair) = relativeSteppers.first(where: {(_, pair) in pair.stepper === clickedOn}) else {
            return
        }
        pair.text.stringValue = pair.stepper.stringValue
        updateSetterFromSteppers()
        updateDate()
    }
    
    func updateSetterFromSteppers() {
        var components = [TimeUnit:Int]()
        for (unit, pair) in relativeSteppers {
            guard let asInt = Int(pair.text.stringValue) else {
                return
            }
            components[unit] = asInt
        }
        epochText.stringValue = String(Int(timeUnitsToInterval(components)))
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
            printRelative.stringValue = "ERROR"
        }
    }
    
    func updateDateDisplays(to date: Date) {
        epochText.stringValue = "\(Int(date.timeIntervalSince1970))"
        
        let timeFormatter = ISO8601DateFormatter()
        timeFormatter.timeZone = TimeZone.utc
        printUtc.stringValue = timeFormatter.string(from: date)
        
        timeFormatter.timeZone = DefaultScheduler.instance.timeZone
        printLocal.stringValue = timeFormatter.string(from: date)
        
        printRelative.stringValue = "\(TimeUtil.daysHoursMinutes(for: date.timeIntervalSince1970, showSeconds: true)) since epoch"
        
        let breakdown = TimeIntervalBreakdown(from: date.timeIntervalSince1970)
        for (key, pair) in relativeSteppers {
            let value = breakdown.componentInterval(for: key)
            pair.stepper.intValue = Int32(value)
            pair.text.intValue = Int32(value)
        }
    }
    
    var date: Date? {
        if let dateAsInt = Int(epochText.stringValue) {
            return Date(timeIntervalSince1970: Double(dateAsInt))
        } else {
            return nil
        }
    }
}

fileprivate struct StepperPair {
    let text: NSTextField
    let stepper: NSStepper
}

protocol DateSetterDeferHandler {
    /// Starts a deferred action, and returns a func to be invoked on un-defer.
    func deferIfNeeded() -> DateSetterDeferredAction?
}

typealias DateSetterDeferredAction = () -> Void

#endif
