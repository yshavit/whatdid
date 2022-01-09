// whatdid?
#if UI_TEST

import Cocoa

class UiTestWindow: NSWindowController, NSWindowDelegate {
    @IBOutlet var mainStack: NSStackView!
    @IBOutlet var componentSelector: NSPopUpButton!
    
    convenience init() {
        self.init(windowNibName: "UiTestWindow")
    }
    
    override func awakeFromNib() {
        componentSelector.removeAllItems()
        add(MainComponent())
        add(AutocompleteComponent())
        add(ButtonWithClosureComponent())
        add(DateRangePickerComponent())
        add(DateRangePaneComponent())
        add(GoalsViewComponent())
    }
    
    private func add(_ use: TestComponent) {
        var className = String(describing: type(of: use))
        let suffix = "Component"
        if className.hasSuffix(suffix) {
            className = String(className.dropLast(suffix.count))
        }
        componentSelector.addItem(withTitle: className)
        let item = componentSelector.itemArray[componentSelector.itemArray.count - 1]
        item.representedObject = use
    }
    
    func show() {
        _ = window?.title // force the window nib to load
        componentSelector.selectItem(at: 0) // the zeroith item
        selectComponentToTest(componentSelector)
        showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func selectComponentToTest(_ sender: NSPopUpButton) {
        mainStack.views.forEach { $0.removeFromSuperview() }
        fitToSize()
        if let use = sender.selectedItem?.representedObject as? TestComponent {
            use.build {
                self.mainStack.addArrangedSubview($0)
                self.fitToSize()
            }
        }
    }
    
    private func fitToSize() {
        if let actualWindow = window, let contentView = window?.contentView {
            actualWindow.setContentSize(contentView.fittingSize)
        }
    }
}

fileprivate class ButtonWithClosureComponent: TestComponent {
    func build(adder: @escaping (NSView) -> Void) {
        let pasteboardButton = ButtonWithClosure()
        pasteboardButton.useAutoLayout()
        adder(pasteboardButton)
        pasteboardButton.setAccessibilityLabel("button_with_closure")
        var counter = Atomic(wrappedValue: 1)
        pasteboardButton.onPress {pasteboardButton in
            let currentCount = counter.map { $0 + 1}
            let labelString = "count=\(currentCount), pressed on self=\(true)"
            let label = NSTextField(labelWithString: labelString)
            label.setAccessibilityEnabled(true)
            label.setAccessibilityLabel(labelString)
            label.setAccessibilityIdentifier("dynamiclabel_\(currentCount)")
            adder(label)
        }
    }
}

fileprivate class MainComponent: TestComponent {
    
    private let schedulerWindow = WhatdidControlHooks()
    
    func build(adder: @escaping (NSView) -> Void) {
        schedulerWindow.build(adder: adder)
    }
    
}

fileprivate class AutocompleteComponent: TestComponent {
    
    private let resultField = NSTextField(labelWithString: "")
    private let autocompleField = AutoCompletingField()
    
    func build(adder: (NSView) -> Void) {
        let options = NSTextField(string: "")
        options.target = self
        options.action = #selector(setAutocompleterOptions(_:))
        options.setAccessibilityIdentifier("test_defineoptions")
        
        autocompleField.action = { self.resultField.stringValue = $0.textField.stringValue }
        autocompleField.setAccessibilityIdentifier("test_autocomplete")
        
        let optionsStack = NSStackView(orientation: .horizontal)
        optionsStack.addArrangedSubview(NSTextField(labelWithString: "options: "))
        optionsStack.addArrangedSubview(options)
        
        resultField.isBordered = true
        resultField.isBezeled = true
        resultField.bezelStyle = .roundedBezel
        resultField.setAccessibilityIdentifier("test_result")
        let resultStack = NSStackView(orientation: .horizontal)
        resultStack.addArrangedSubview(NSTextField(labelWithString: "result: "))
        resultStack.addArrangedSubview(resultField)
        
        adder(optionsStack)
        adder(resultStack)
        adder(autocompleField)
        optionsStack.arrangedSubviews[1].leadingAnchor.constraint(equalTo: resultStack.arrangedSubviews[1].leadingAnchor).isActive = true
        
        options.nextKeyView = autocompleField
        autocompleField.nextKeyView = options
        
        setAutocompleterOptions(options)
    }
    
    @objc private func setAutocompleterOptions(_ sender: NSTextField) {
        let options = sender.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces)}
        autocompleField.options = options
    }
}

fileprivate class DateRangePickerComponent: TestComponent {
    func build(adder: (NSView) -> Void) {
        let picker = DateRangePicker()
        picker.controlSize = .small
        picker.setAccessibilityIdentifier("picker")
        
        let fromText = NSTextField(labelWithString: "FROM")
        fromText.setAccessibilityIdentifier("result_start")
        let toText = NSTextField(labelWithString: "TO")
        toText.setAccessibilityIdentifier("result_end")
        let diff = NSTextField(labelWithString: "DIFF")
        diff.setAccessibilityIdentifier("result_diff")
        adder(picker)
        adder(fromText)
        adder(toText)
        adder(diff)
        picker.onDateSelection {from, to, _ in
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = DefaultScheduler.instance.timeZone
            fromText.stringValue = formatter.string(from: from)
            toText.stringValue = formatter.string(from: to)
            diff.stringValue = TimeUtil.daysHoursMinutes(for: to.timeIntervalSince(from))
        }
        adder(createCalendarCalibrationHelper())
    }
    
    private func createCalendarCalibrationHelper() -> NSView {
        let picker = ReportingNSDatePicker()
        picker.timeZone = DefaultScheduler.instance.timeZone
        picker.datePickerStyle = .clockAndCalendar
        picker.datePickerElements = .yearMonthDay
        picker.datePickerMode = .single
        picker.setAccessibilityIdentifier("calendar_calibration")
        picker.dateValue = Prefs.dayStartTime.map {hh, mm in
            TimeUtil.dateForTime(.previous, hh: hh, mm: mm)
        }
        picker.maxDate = picker.dateValue
        
        let popover = NSPopover()
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = picker
        popover.behavior = .applicationDefined
        popover.contentSize = picker.intrinsicContentSize
        
        let toggleButton = ButtonWithClosure(checkboxWithTitle: "Show dummy calendar", target: nil, action: nil)
        toggleButton.setAccessibilityIdentifier("show_calendar_calibration")
        toggleButton.onPress {me in
            if me.state == .on {
                popover.show(relativeTo: NSRect.zero, of: toggleButton, preferredEdge: .maxY)
            } else {
                popover.close()
            }
        }
        return toggleButton
    }
    
    private class ReportingNSDatePicker: NSDatePicker {
        
        override func accessibilityValue() -> Any? {
            var calendar = DefaultScheduler.instance.calendar
            calendar.timeZone = DefaultScheduler.instance.timeZone
            
            let yy = calendar.component(.year, from: dateValue)
            let mm = calendar.component(.month, from: dateValue)
            let dd = calendar.component(.day, from: dateValue)
            return "\(yy)-\(mm)-\(dd)"
        }
    }
}

fileprivate class DateRangePaneComponent: TestComponent {
    func build(adder: @escaping (NSView) -> Void) {
        let pane = DateRangePane()
        pane.prepareToShow()
        adder(pane)
    }
}

fileprivate class GoalsViewComponent: TestComponent {
    
    private var goalsView: GoalsView?
    
    func build(adder: @escaping (NSView) -> Void) {
        let g1 = add(GoalsView(), to: adder)
        
        let box = add(NSBox(), to: adder)
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 350).isActive = true
        
        let g2 = add(GoalsView(), to: adder)
        for g in [g1, g2] {
            g.widthAnchor.constraint(equalTo: box.widthAnchor).isActive = true
        }
        
        adder(NSButton(title: "sync goals", target: self, action: #selector(self.resetGoalViews(_:))))
    }
    
    @objc private func resetGoalViews(_ pasteboardButton: NSButton) {
        pasteboardButton.superview?.subviews.compactMap({$0 as? GoalsView}).forEach({$0.reset()})
    }
}

fileprivate protocol TestComponent {
    func build(adder: @escaping (NSView) -> Void)
}

extension TestComponent {
    func add<T: NSView>(_ element: T, to adder: (NSView) -> Void) -> T {
        adder(element)
        return element
    }
}

#endif
