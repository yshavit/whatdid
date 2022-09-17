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
        add(TextFieldWithPopupComponent())
        add(TextOptionsListComponent())
        add(AutocompleteComponent())
        add(ButtonWithClosureComponent())
        add(DateRangePaneComponent())
        add(DateRangePickerComponent())
        add(GoalsViewComponent())
        add(SegmentedTimelineViewComponent())
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

fileprivate func hStack(label: String?, _ elems: NSView...) -> NSView {
    let hStack = NSStackView(orientation: .horizontal)
    if let label = label {
        let labelField = NSTextField(labelWithString: label + ":")
        labelField.font = NSFont.labelFont(ofSize: NSFont.systemFontSize(for: .small))
        hStack.addArrangedSubview(labelField)
    }
    elems.forEach(hStack.addArrangedSubview)
    return hStack
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

fileprivate class TextFieldWithPopupComponent: TestComponent {
    func build(adder: (NSView) -> Void) {
        let field = TextFieldWithPopup()
        field.contents = DummyPopupContents()

        let echo = NSTextField(labelWithString: "")
        field.onTextChange = {
            echo.stringValue = field.stringValue
        }
        
        adder(echo)
        adder(field)
    }
    
    class DummyPopupContents: TextFieldWithPopupContents {
        
        var selectedText: String? // always nill; needed for protocol
        
        private var callbacks: TextFieldWithPopupCallbacks!

        private let mainStack = NSStackView(orientation: .vertical)
        var asView: NSView {
            get {
                mainStack
            }
        }
        
        func willShow(callbacks: TextFieldWithPopupCallbacks) {
            mainStack.spacing = 4
            self.callbacks = callbacks
            mainStack.subviews = []
            moveSelection(.down)
        }
        
        func handleClick(at point: NSPoint) -> String? {
            guard let superview = asView.superview else {
                wdlog(.warn, "Couldn't find superview (to convert local NSPoint to)")
                return nil
            }
            let pointInSuper = asView.convert(point, to: superview)
            return (asView.hitTest(pointInSuper) as? NSTextField)?.stringValue
        }
        
        func moveSelection(_ direction: Direction) {
            func scrollTo(_ elem: NSView?) {
                guard let elem = elem else {
                    return
                }
                callbacks.scroll(to: elem.bounds, within: elem)
                if let text = (elem as? NSTextField)?.stringValue {
                    callbacks.setText(to: text)
                }
            }
            
            switch (direction) {
            case .up:
                mainStack.arrangedSubviews.last?.removeFromSuperview()
                callbacks.contentSizeChanged()
                scrollTo(mainStack.arrangedSubviews.first)
            case .down:
                let label = NSTextField(labelWithString: "label #\(mainStack.arrangedSubviews.count + 1)")
                label.isBordered = true
                mainStack.addArrangedSubview(label)
                callbacks.contentSizeChanged()
                scrollTo(mainStack.arrangedSubviews.last)
            }
            mainStack.invalidateIntrinsicContentSize()
        }
        
        func onTextChanged(to newValue: String) -> String {
            return "the quick brown fox jumped over the lazy dog"
        }
        
        func didHide() {
            // nothing
        }
    }
}

fileprivate class TextOptionsListComponent: TestComponent, TextFieldWithPopupCallbacks {
    
    private let stepperEcho = NSTextField(labelWithString: "")
    private let textOptionsAutocompleteEcho = NSTextField(labelWithString: "")
    private let textOptionsResult = NSTextField(labelWithString: "")
    private let textOptionsList = TextOptionsList()
    
    func build(adder: (NSView) -> Void) {
        textOptionsList.willShow(callbacks: self)
        
        let stepper = NSStepper()
        stepper.minValue = 0
        // max value is optionSegments.count!
        stepper.maxValue = Double(generateOptions(max: nil).count)
        stepper.intValue = 4
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(handleStepperChange(_:))
        handleStepperChange(stepper)
        
        let matchInput = NSTextField(string: "")
        matchInput.target = self
        matchInput.action = #selector(handleMatchInput(_:))
        
        textOptionsAutocompleteEcho.isBordered = true
        
        adder(hStack(label: "# options", stepperEcho, stepper))
        adder(hStack(
            label: "keyboard selection",
            ButtonWithClosure(label: "▲", {_ in self.textOptionsList.moveSelection(.up)}),
            ButtonWithClosure(label: "▼", {_ in self.textOptionsList.moveSelection(.down)})
        ))
        adder(hStack(label: "input", matchInput))
        adder(hStack(label: "autocompletes to", textOptionsAutocompleteEcho))
        adder(hStack(label: "result", textOptionsResult))
        adder(textOptionsList)
        if let parent = textOptionsList.superview {
            textOptionsList.widthAnchor.constraint(equalTo: parent.widthAnchor).isActive = true
        }
    }
    
    func contentSizeChanged() {
        // nothing
    }
    
    func scroll(to bounds: NSRect, within: NSView) {
        // nothing
    }
    
    func setText(to string: String) {
        textOptionsResult.stringValue = string
    }
    
    @objc private func handleStepperChange(_ stepper: NSStepper) {
        stepperEcho.stringValue = "\(stepper.intValue)"
        textOptionsList.options = generateOptions(max: stepper.intValue)
    }
    
    @objc private func handleMatchInput(_ textField: NSTextField) {
        textOptionsAutocompleteEcho.stringValue = textOptionsList.onTextChanged(to: textField.stringValue)
    }
    
    private func generateOptions(max: Int32?) -> [String] {
        let segment1Options = ["alpha", "bravo", "charlie", "delta"]
        let segment2Options = ["one", "2", "three", "four"]
        
        var results = segment1Options.flatMap {seg1 in
            segment2Options.map {seg2 in
                "\(seg1) \(seg2)"
            }
        }
        if let max = max, max < results.count {
            results = results.dropLast(results.count - Int(max))
        }
        return results
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
        
        autocompleField.onAction = { self.resultField.stringValue = $0.stringValue }
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
        
        let separator = NSBox()
        separator.boxType = .separator
        adder(separator)
        
        adder(ButtonWithClosure(label: "Load lots of data", {_ in
            var bigOptionsList = [String]()
            wdlog(.info, "Autocomplete data: generating")
            for i in 1..<1000 {
                bigOptionsList.append("option \(i)")
            }
            
            wdlog(.info, "Autocomplete data: setting")
            self.autocompleField.options = bigOptionsList
            
            wdlog(.info, "Autocomplete data: done")
        }))
        
        options.nextKeyView = autocompleField
        autocompleField.nextKeyView = options
        
        setAutocompleterOptions(options)
    }
    
    @objc private func setAutocompleterOptions(_ sender: NSTextField) {
        let options = sender.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces)}
        autocompleField.options = options
    }
}

fileprivate class DateRangePaneComponent: TestComponent {
    func build(adder: @escaping (NSView) -> Void) {
        let pane = DateRangePane()
        adder(pane)
        let separator = NSBox()
        separator.boxType = .separator
        pane.onChange = createDateRangeValidators(to: adder)
        adder(separator)
        adder(createCalendarCalibrationHelper())
        pane.prepareToShow()
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

fileprivate class DateRangePickerComponent: TestComponent {
    func build(adder: (NSView) -> Void) {
        let picker = DateRangePicker()
        picker.setAccessibilityIdentifier("picker")
        
        adder(picker)
        let dateUpdater = createDateRangeValidators(to: adder)
        picker.onDateSelection {from, to, _ in
            dateUpdater(from, to)
        }
    }
}

fileprivate func createDateRangeValidators(to adder: (NSView) -> Void) -> ((Date, Date) -> Void) {
    let fromText = NSTextField(labelWithString: "FROM")
    fromText.setAccessibilityIdentifier("result_start")
    let toText = NSTextField(labelWithString: "TO")
    toText.setAccessibilityIdentifier("result_end")
    let diff = NSTextField(labelWithString: "DIFF")
    diff.setAccessibilityIdentifier("result_diff")
    adder(fromText)
    adder(toText)
    adder(diff)
    
    return {from, to in
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = DefaultScheduler.instance.timeZone
        fromText.stringValue = formatter.string(from: from)
        toText.stringValue = formatter.string(from: to)
        diff.stringValue = TimeUtil.daysHoursMinutes(for: to.timeIntervalSince(from))
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

fileprivate class SegmentedTimelineViewComponent: TestComponent {
    func build(adder: @escaping (NSView) -> Void) {
        func project(_ project: String, from: Int, to: Int) -> FlatEntry {
            return FlatEntry(
                from: Date(timeIntervalSince1970: Double(from)),
                to: Date(timeIntervalSince1970: Double(to)),
                project: project,
                task: "",
                notes: nil)
        }
        
        let segmentedTimelineView = SegmentedTimelineView()
        segmentedTimelineView.setEntries([
            project("alpha", from: 4, to: 5),
            project("alpha", from: 5, to: 6),
            project("bravo", from: 6, to: 7),
            project("alpha", from: 8, to: 10),
        ])
        adder(segmentedTimelineView)
        segmentedTimelineView.autoresizingMask = [.height, .width]
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
