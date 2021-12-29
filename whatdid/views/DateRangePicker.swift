// whatdid?

import Cocoa

class DateRangePicker: NSView {
    
    private static let MODE_ONE_DAY = "single day"
    private static let MODE_RANGE = "date range"
    
    private let topStack = NSStackView(orientation: .horizontal)
    private let modePicker = NSPopUpButton()
    private let datePicker = NSDatePicker()
    private let popover = NSPopover()
    private var handlers = [(from: Date, to: Date) -> Void]()
    private var thisMorning: Date = Prefs.dayStartTime.map {hh, mm in
        TimeUtil.dateForTime(.previous, hh: hh, mm: mm)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        doInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        doInit()
    }
    
    private func doInit() {
        addSubview(topStack)
        topStack.anchorAllSides(to: self)
        
        let notifyingCell = NotifyingNSPopUpButtonCell()
        modePicker.cell = notifyingCell
        modePicker.addItems(withTitles: ["today", "yesterday", "custom"])
        notifyingCell.handler = {cell in
            while cell.numberOfItems > 3 {
                cell.selectItem(at: 2)
                cell.removeItem(at: 3)
            }
        }
        modePicker.bezelStyle = .inline
        modePicker.target = self
        modePicker.action = #selector(self.changeMode(_:))
        
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = datePicker
        popover.behavior = .semitransient
        
        datePicker.datePickerStyle = .clockAndCalendar
        datePicker.datePickerElements = .yearMonthDay
        datePicker.datePickerMode = .range
        datePicker.calendar = DefaultScheduler.instance.calendar
        datePicker.timeZone = DefaultScheduler.instance.timeZone
        datePicker.target = self
        datePicker.action = #selector(self.pickDate(_:))
        
        if #available(macOS 10.15.4, *) {
            datePicker.presentsCalendarOverlay = true
        }
        
        topStack.addArrangedSubview(modePicker)
        prepareToShow()
    }
    
    override func setAccessibilityIdentifier(_ accessibilityIdentifier: String?) {
        modePicker.setAccessibilityIdentifier(accessibilityIdentifier)
    }
    
    func prepareToShow() {
        thisMorning = Prefs.dayStartTime.map {hh, mm in
            TimeUtil.dateForTime(.previous, hh: hh, mm: mm)
        }
        datePicker.maxDate = thisMorning
        datePicker.dateValue = thisMorning
        onDateSelection(self.updateMenuItemsFor(start:end:))
    }

    /// Registers a handler to get notifications about date selections.
    ///
    /// The date range covers the full range of Dates for which we should fetch data, and are always anchored at "morning"
    /// (whatever the user has configured that to be).
    ///
    /// For example, if the user selected a single day, then the `from` argument is the morning of that day, and the `to`
    /// argument is the following morning.
    func onDateSelection(_ handler: @escaping (_ from: Date, _ to: Date) -> Void) {
        handlers.append(handler)
        let (start, end) = startAndEndDates
        handler(start, end)
    }
    
    private func updateMenuItemsFor(start: Date, end: Date) {
        let cal = DefaultScheduler.instance.calendar
        let tomorrowMorning = cal.date(byAdding: .day, value: 1, to: thisMorning)
        let yesterdayMorning = cal.date(byAdding: .day, value: -1, to: thisMorning)
        
        if start == thisMorning && end == tomorrowMorning {
            modePicker.selectItem(at: 0)
        } else if (start == yesterdayMorning && end == thisMorning) {
            modePicker.selectItem(at: 1)
        } else {
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("dMMM")
            func format(_ date: Date) -> String {
                if (date == yesterdayMorning) {
                    return "yesterday"
                } else if (date == thisMorning) {
                    return "today"
                } else {
                    return formatter.string(from: date)
                }
            }
            let lastFullDay = cal.date(byAdding: .day, value: -1, to: end)!
            let customText: String
            if start == lastFullDay {
                customText = format(start)
            } else {
                let conjunction = (cal.date(byAdding: .day, value: 1, to: start) == lastFullDay) ? "and" : "through"
                customText = "\(format(start)) \(conjunction) \(format(lastFullDay))"
            }
            
            self.modePicker.addItem(withTitle: customText)
            self.modePicker.selectItem(at: 3)
        }
        self.popover.close()
    }
    
    var controlSize: NSControl.ControlSize {
        get {
            modePicker.controlSize
        }
        set (value) {
            modePicker.controlSize = value
            datePicker.controlSize = value
        }
    }
    
    @objc private func changeMode(_ sender: NSPopUpButton) {
        let selected = sender.selectedItem?.title
        if selected == "today" {
            datePicker.dateValue = thisMorning
            datePicker.timeInterval = 0
            notifyHandlers()
        } else if (selected == "yesterday") {
            let yesterday = DefaultScheduler.instance.calendar.date(byAdding: .day, value: -1, to: thisMorning)!
            datePicker.dateValue = yesterday
            datePicker.timeInterval = 0
            notifyHandlers()
        }
        if selected == "custom" {
            popover.contentViewController?.view.layoutSubtreeIfNeeded()
            popover.contentSize = datePicker.intrinsicContentSize
            popover.show(relativeTo: NSRect.zero, of: sender, preferredEdge: .maxX)
        }
    }
    
    private func notifyHandlers() {
        let (start, end) = startAndEndDates
        for handler in handlers {
            handler(start, end)
        }
    }
    
    private var startAndEndDates: (Date, Date) {
        let pickedStart = datePicker.dateValue
        let pickedEnd = pickedStart.addingTimeInterval(datePicker.timeInterval)
        // The pickedEnd is the morning of whatever the last day the user picked. But we want to cover that full day,
        // so the actual end range is the *following* morning.
        // For example, let's say I picked March 14 (just that one day). In that case, pickedStart and pickedEnd are both
        // March 14, at 9:00am (assuming that's the day's start).
        // But I want to see everything that happened on March 14, which means a range from March 14 09:00 to March 15 09:00.
        let actualEnd = DefaultScheduler.instance.calendar.date(byAdding: .day, value: 1, to: pickedEnd)!
        return (pickedStart, actualEnd)
    }
    
    @objc private func pickDate(_ sender: NSDatePicker) {
        // For some reason, datePicker.sendAction(on: .leftMouseUp) doesn't work. So, ignore all other events.
        guard NSApp.currentEvent?.type == .leftMouseUp else {
            return
        }
        notifyHandlers()
    }
    
    private class NotifyingNSPopUpButtonCell: NSPopUpButtonCell {
        
        fileprivate var handler: ((NSPopUpButtonCell) -> Void) = {_ in }
        
        override func attachPopUp(withFrame cellFrame: NSRect, in controlView: NSView) {
            handler(self)
            super.attachPopUp(withFrame: cellFrame, in: controlView)
        }
    }
}
