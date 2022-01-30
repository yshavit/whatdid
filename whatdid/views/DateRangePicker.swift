// whatdid?

import Cocoa

@IBDesignable
class DateRangePicker: NSPopUpButton, NSPopoverDelegate {
    
    private static let MODE_ONE_DAY = "single day"
    private static let MODE_RANGE = "date range"
    
    private let dateRangePane = DateRangePane()
    private var customDateRange: (Date, Date)?
    private let popover = NSPopover()
    private var handlers = [(from: Date, to: Date, because: UpdateReason) -> Void]()
    private var currentTitle = Title.yesterday
    private var thisMorning: Date = Prefs.dayStartTime.map {hh, mm in
        TimeUtil.dateForTime(.previous, hh: hh, mm: mm)
    }
    
    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        doInit()
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
        addItems(withTitles: ["today", "yesterday", "custom"])
        currentTitle = .today
        if let cell = cell as? NSPopUpButtonCell {
            cell.arrowPosition = .noArrow
            cell.usesItemFromMenu = false
            cell.menuItem = NSMenuItem(title: itemTitles[0], action: nil, keyEquivalent: "")
        } else {
            wdlog(.warn, "modePicker's cell was not NSPopUpButtonCell")
        }
        bezelStyle = .roundRect // roundRect, textureRounded
        focusRingType = .none
        
        target = self
        action = #selector(self.changeMode(_:))
        
        popover.contentViewController = NonFocusingNSViewController()
        popover.contentViewController?.view = dateRangePane
        popover.behavior = .semitransient
        popover.delegate = self
        dateRangePane.onChange = {_, _ in
            self.notifyHandlers(because: .userAction)
        }
        
        onDateSelection(self.updateMenuItemsFor(start:end:because:))
        prepareToShow()
    }
    
    override func prepareForInterfaceBuilder() {
        doInit()
        prepareToShow()
        invalidateIntrinsicContentSize()
    }
    
    func prepareToShow() {
        thisMorning = Prefs.dayStartTime.map {hh, mm in
            TimeUtil.dateForTime(.previous, hh: hh, mm: mm)
        }
        dateRangePane.prepareToShow()
        notifyHandlers(because: .prepareToShow)
    }

    /// Registers a handler to get notifications about date selections.
    ///
    /// The date range covers the full range of Dates for which we should fetch data, and are always anchored at "morning"
    /// (whatever the user has configured that to be).
    ///
    /// For example, if the user selected a single day, then the `from` argument is the morning of that day, and the `to`
    /// argument is the following morning.
    func onDateSelection(_ handler: @escaping (_ from: Date, _ to: Date, _ because: UpdateReason) -> Void) {
        handlers.append(handler)
        let (start, end) = startAndEndDates
        handler(start, end, .initial)
    }
    
    fileprivate func updateMenuItemsFor(start: Date, end: Date, because reason: UpdateReason) {
        if reason == .initial {
            return
        }
        let modePickerCell = cell as? NSPopUpButtonCell
        let cal = DefaultScheduler.instance.calendar
        let tomorrowMorning = cal.date(byAdding: .day, value: 1, to: thisMorning)
        let yesterdayMorning = cal.date(byAdding: .day, value: -1, to: thisMorning)
        
        if start == thisMorning && end == tomorrowMorning {
            selectItem(at: 0)
            currentTitle = .today
            customDateRange = nil
            modePickerCell?.menuItem = selectedItem
        } else if (start == yesterdayMorning && end == thisMorning) {
            selectItem(at: 1)
            currentTitle = .yesterday
            customDateRange = nil
            modePickerCell?.menuItem = selectedItem
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
            modePickerCell?.menuItem = NSMenuItem(title: customText, action: nil, keyEquivalent: "")
            currentTitle = .custom(title: customText)
            selectItem(at: 2)
            
            // We need to reverse the +1d that happened in startAndEndDates. See that comment for why it happens.
            // Basically, the problem is that DateRangePane is focused on the actual NSDatePicker options, in which
            // the end-date is the start of the last selected day. This class (DateRangePicker) uses the end date as the
            // start of the *next* day (so that the actual range reflects all of today). So, we need to translate back
            // to that NSDatePicker-based view.
            customDateRange = (start, DefaultScheduler.instance.calendar.date(byAdding: .day, value: -1, to: end)!)
        }
        popover.close()
    }
    
    @objc private func changeMode(_ sender: NSPopUpButton) {
        let selected = sender.selectedItem?.title
        if selected == "today" {
            dateRangePane.dateRange = (thisMorning, thisMorning)
            notifyHandlers(because: .userAction)
            currentTitle = .today
        } else if (selected == "yesterday") {
            let yesterday = DefaultScheduler.instance.calendar.date(byAdding: .day, value: -1, to: thisMorning)!
            dateRangePane.dateRange = (yesterday, yesterday)
            notifyHandlers(because: .userAction)
            currentTitle = .yesterday
        } else {
            popover.contentViewController?.view.layoutSubtreeIfNeeded()
            popover.contentSize = dateRangePane.intrinsicContentSize
            dateRangePane.prepareToShow()
            if let initialDateRange = customDateRange {
                dateRangePane.dateRange = initialDateRange
            }
            let modePickerCell = cell as? NSPopUpButtonCell
            modePickerCell?.menuItem = NSMenuItem(title: "custom", action: nil, keyEquivalent: "")
            popover.show(relativeTo: NSRect.zero, of: sender, preferredEdge: .maxX)
        }
    }
    
    func popoverDidClose(_ notification: Notification) {
        // This could happen for one of two reasons: either the user selected a custom date, or they clicked outside the
        // popover (and thus dismissed it). In the latter case, we want to restore the old state, and specifically the selected
        // item.
        // For example, let's say the item is currently on "today". I click on the button to show the popdown menu, and then
        // click "custom" -- that's now the selected item. The popover shows, but I click away to dismiss it. The picker should
        // still be set to "today", and the button title will show that (since it didn't get any update notification), but the
        // selected item will still say "custom". We need to change it back.
        // Note that this means that when we pick a custom date, we actually set the button and menu item twice: once as part
        // of setting it, and then once again when the popover closes. I'm not too worried about that small amount of inefficiency.
        let newTitle: String
        let newIndex: Int
        switch currentTitle {
        case .today:
            newIndex = 0
            newTitle = "today"
        case .yesterday:
            newIndex = 1
            newTitle = "yesterday"
        case .custom(title: let title):
            newIndex = 2
            newTitle = title
        }
        selectItem(at: newIndex)
        let modePickerCell = cell as? NSPopUpButtonCell
        modePickerCell?.menuItem = NSMenuItem(title: newTitle, action: nil, keyEquivalent: "")
    }
    
    override func accessibilityValue() -> Any? {
        let cell = cell as? NSPopUpButtonCell
        return cell?.menuItem?.title
    }
    
    private func notifyHandlers(because reason: UpdateReason) {
        let (start, end) = startAndEndDates
        for handler in handlers {
            handler(start, end, reason)
        }
    }
    
    private var startAndEndDates: (Date, Date) {
        let (pickedStart, pickedEnd) = dateRangePane.dateRange
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
        notifyHandlers(because: .userAction)
    }
    
    private enum Title {
        case yesterday
        case today
        case custom(title: String)
    }
}

enum UpdateReason {
    case initial
    case prepareToShow
    case userAction
}
