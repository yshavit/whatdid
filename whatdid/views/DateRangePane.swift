// whatdid?

import Cocoa

@IBDesignable
class DateRangePane: NSView {
    
    private var hourInDay = 0
    private var minuteInDay = 0
    
    private let rangeDatePicker = NSDatePicker()
    private let disclosure = DisclosureWithLabel()
    private let startDatePicker = NSDatePicker()
    private let endDatePicker = NSDatePicker()
    
    var onChange: (Date, Date) -> Void = {_, _ in }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        doInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        doInit()
    }
    
    private func doInit() {
        forEachPicker {picker in
            picker.datePickerElements = .yearMonthDay
            picker.calendar = DefaultScheduler.instance.calendar
            picker.timeZone = DefaultScheduler.instance.timeZone
            picker.target = self
        }
        
        rangeDatePicker.datePickerStyle = .clockAndCalendar
        rangeDatePicker.datePickerMode = .range
        rangeDatePicker.action = #selector(self.rangeDatePickerAction(_:))
        
        startDatePicker.datePickerStyle = .textField
        startDatePicker.action = #selector(self.endpointPickerChanged(_:))
        
        endDatePicker.datePickerStyle = .textField
        endDatePicker.action = #selector(self.endpointPickerChanged(_:))
        
        if #available(macOS 10.15.4, *) {
            startDatePicker.presentsCalendarOverlay = true
            endDatePicker.presentsCalendarOverlay = true
        }
        let okButton = NSButton(title: "ok", target: self, action: #selector(self.submit(_:)))
        
        okButton.controlSize = .small
        [startDatePicker, endDatePicker].forEach {$0.font = NSFont.labelFont(ofSize: NSFont.systemFontSize(for: .small))}
        
        func gridLabel(_ label: String) -> NSView {
            return NSTextField(labelWithAttributedString: NSAttributedString(string: label, attributes: [
                .font: NSFont.labelFont(ofSize: NSFont.systemFontSize(for: .small))
            ]))
        }
        
        let stepperGrid = NSGridView(views: [
            [gridLabel("from"), startDatePicker, NSView()],
            [gridLabel("to"), endDatePicker, okButton]
        ])
        stepperGrid.rowSpacing = 2
        stepperGrid.columnSpacing = 2
        stepperGrid.yPlacement = .center
        let okCell = stepperGrid.cell(atColumnIndex: 2, rowIndex: 1)
        okCell.xPlacement = .trailing
        
        disclosure.detailsView = stepperGrid
        disclosure.title = "details"
        disclosure.controlSize = .small
        
        let vStack = NSStackView(orientation: .vertical)
        vStack.alignment = .leading
        vStack.addArrangedSubview(rangeDatePicker)
        vStack.addArrangedSubview(disclosure)
        vStack.addArrangedSubview(stepperGrid)
        stepperGrid.widthAnchor.constraint(equalTo: rangeDatePicker.widthAnchor).isActive = true
        
        addSubview(vStack)
        vStack.anchorAllSides(to: self)
        prepareToShow()
    }
    
    override func prepareForInterfaceBuilder() {
        doInit()
        prepareToShow()
        invalidateIntrinsicContentSize()
    }
    
    func prepareToShow() {
        let thisMorning = Prefs.dayStartTime.map {hh, mm in
            TimeUtil.dateForTime(.previous, hh: hh, mm: mm)
        }
        forEachPicker {picker in
            picker.dateValue = thisMorning
            picker.maxDate = thisMorning
        }
    }
    
    @objc private func rangeDatePickerAction(_ sender: NSDatePicker) {
        startDatePicker.dateValue = sender.dateValue
        endDatePicker.dateValue = sender.dateValue.addingTimeInterval(sender.timeInterval)
        if NSApp.currentEvent?.type == .leftMouseUp && !disclosure.isShowingDetails {
            notifyHandler()
        }
    }
    
    @objc private func endpointPickerChanged(_ sender: NSDatePicker) {
        if sender == startDatePicker {
            endDatePicker.dateValue = max(startDatePicker.dateValue, endDatePicker.dateValue)
        } else if sender == endDatePicker {
            startDatePicker.dateValue = min(startDatePicker.dateValue, endDatePicker.dateValue)
        } else {
            wdlog(.warn, "unrecognized date picker selected")
        }
        
        let start = startDatePicker.dateValue
        rangeDatePicker.dateValue = start
        rangeDatePicker.timeInterval = endDatePicker.dateValue.timeIntervalSince(start)
    }
    
    @objc private func submit(_ sender: NSButton) {
        notifyHandler()
    }
    
    private func notifyHandler() {
        let startDate = startDatePicker.dateValue
        let endDate = startDatePicker.dateValue
        // some sanity checking of invariants
        if startDate != rangeDatePicker.dateValue {
            wdlog(.warn, "Start date picker was %@, but range picker's start was %@",
                  startDate as NSDate,
                  rangeDatePicker.dateValue as NSDate)
        }
        let rangeEnd = rangeDatePicker.dateValue.addingTimeInterval(rangeDatePicker.timeInterval)
        if endDate != rangeEnd {
            wdlog(.warn, "End date picker was %@, but range picker's end was %@",
                  endDate as NSDate,
                  rangeEnd as NSDate)
        }
        // and then do the actual notification
        onChange(startDate, endDate)
    }
    
    private func forEachPicker(_ action: (NSDatePicker) -> Void) {
        [startDatePicker, endDatePicker, rangeDatePicker].forEach(action)
    }
}
