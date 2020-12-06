// whatdid?

import Cocoa
import KeyboardShortcuts

class PrefsViewController: NSViewController {
    @Pref(key: "prefsview.openItem") static var openTab = 0
    
    @IBOutlet private var outerVStackWidth: NSLayoutConstraint!
    @IBOutlet var outerVStackMinHeight: NSLayoutConstraint!
    private var desiredWidth: CGFloat = 0
    private var minHeight: CGFloat = 0
    
    @IBOutlet var tabButtonsStack: NSStackView!
    @IBOutlet var mainTabs: NSTabView!
    
    var ptnScheduleChanged: () -> Void = {}
    
    @IBInspectable
    dynamic var ptnFrequencyMinutes: Int {
        get {
            Prefs.ptnFrequencyMinutes
        } set(value) {
            let adjusted = value.clipped(to: 5...120)
            if (value == adjusted) {
                Prefs.ptnFrequencyMinutes = adjusted
                let tmp = ptnFrequencyJitterMinutes
                ptnFrequencyJitterMinutes = tmp // this will auto-clip the value if needed, and call the change handler
            } else {
                RunLoop.current.perform { self.ptnFrequencyMinutes = adjusted }
            }
        }
    }
    
    @IBInspectable
    dynamic var ptnFrequencyJitterMinutes: Int {
        get {
            Prefs.ptnFrequencyJitterMinutes
        } set (value) {
            let adjusted = value.clipped(to: 0...(ptnFrequencyMinutes / 2))
            if (value == adjusted) {
                Prefs.ptnFrequencyJitterMinutes = adjusted
                ptnScheduleChanged()
            } else {
                RunLoop.current.perform { self.ptnFrequencyJitterMinutes = adjusted }
            }
        }
    }
    
    @IBInspectable
    dynamic var launchAtLogin: Bool {
        get {
            Prefs.launchAtLogin
        } set(value) {
            Prefs.launchAtLogin = value
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        outerVStackWidth.constant = desiredWidth
        outerVStackMinHeight.constant = minHeight
        
        tabButtonsStack.wantsLayer = true
        
        tabButtonsStack.subviews.forEach {$0.removeFromSuperview()}
        for (i, tab) in mainTabs.tabViewItems.enumerated() {
            let text = tab.label
            let button = ButtonWithClosure(label: text) {_ in
                self.selectPane(at: i)
            }
            button.bezelStyle = .smallSquare
            button.image = tab.value(forKey: "image") as? NSImage
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.setButtonType(.pushOnPushOff)
            button.focusRingType = .none
            button.setAccessibilityRole(.button)
            button.setAccessibilitySubrole(.tabButtonSubrole)
            tabButtonsStack.addArrangedSubview(button)
        }
        tabButtonsStack.addArrangedSubview(NSView()) // trailing spacer
        
        setUpGeneralPanel()
        setUpAboutPanel()
    }
    
    override func viewWillAppear() {
        NSAppearance.withEffectiveAppearance {
            tabButtonsStack.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        if !mainTabs.tabViewItems.isEmpty {
            selectPane(at: PrefsViewController.openTab)
        }
    }
    
    private func selectPane(at index: Int) {
        for (otherButtonIdx, subview) in self.tabButtonsStack.arrangedSubviews.enumerated() {
            let state: NSControl.StateValue = otherButtonIdx == index ? .on : .off
            (subview as? NSButton)?.state = state
        }
        self.mainTabs.selectTabViewItem(at: index)
        view.layoutSubtreeIfNeeded()
        view.window?.setContentSize(view.fittingSize)
        PrefsViewController.openTab = index
    }

    func setSize(width: CGFloat, minHeight: CGFloat) {
        self.desiredWidth = width
        self.minHeight = minHeight
    }
    
    @IBAction func quitButton(_ sender: Any) {
        endParentSheet(with: .stop)
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        endParentSheet(with: .cancel)
    }
    
    private func endParentSheet(with response: NSApplication.ModalResponse) {
        if let myWindow = view.window, let mySheetParent = myWindow.sheetParent {
            mySheetParent.endSheet(myWindow, returnCode: response)
        }
    }
    
    override func viewDidDisappear() {
        // Set the new daily report time, and reschedule it (it's fine if it's unchanged)
        Prefs.dailyReportTime = getHhMm(for: dailyReportTime)
        AppDelegate.instance.mainMenu.schedule(.dailyEnd)
        let snoozeInfo = snoozeUntilTomorrowInfo
        Prefs.dayStartTime = snoozeInfo.hhMm
        Prefs.daysIncludeWeekends = snoozeInfo.includeWeekends
    }
    
    //------------------------------------------------------------------
    // General
    //------------------------------------------------------------------
    
    @IBOutlet var dayStartTimePicker: NSDatePicker!
    @IBOutlet var daysIncludeWeekends: NSButton!
    
    @IBOutlet var dailyReportTime: NSDatePicker!
    
    @IBOutlet var globalShortcutHolder: NSView!
    
    let calendarForDateTimePickers = Calendar.current // doesn't actually matter what it is, so long as it's consistent
    
    private func setUpGeneralPanel() {
        let recorder = KeyboardShortcuts.RecorderCocoa(for: .grabFocus)
        globalShortcutHolder.addSubview(recorder)
        recorder.anchorAllSides(to: globalShortcutHolder)
        
        func setTimePicker(_ picker: NSDatePicker, to time: HoursAndMinutes) {
            picker.calendar = calendarForDateTimePickers
            picker.timeZone = calendarForDateTimePickers.timeZone
            var dateComponents = DateComponents()
            time.read() {hours, minutes in
                dateComponents.hour = hours
                dateComponents.minute = minutes
            }
            dateComponents.calendar = calendarForDateTimePickers
            dateComponents.timeZone = calendarForDateTimePickers.timeZone
            NSLog("Converting DateComponents to Date: \(dateComponents)")
            if let date = dateComponents.date {
                picker.dateValue = date
            } else {
                NSLog("Couldn't convert DateComponents to Date: \(dateComponents)")
            }
        }
        setTimePicker(dailyReportTime, to: Prefs.dailyReportTime)
        setTimePicker(dayStartTimePicker, to: Prefs.dayStartTime)
        daysIncludeWeekends.state = Prefs.daysIncludeWeekends ? .on : .off
    }
    
    func getHhMm(for picker: NSDatePicker) -> HoursAndMinutes {
        let components = calendarForDateTimePickers.dateComponents([.hour, .minute], from: picker.dateValue)
        return HoursAndMinutes(hours: components.hour!, minutes: components.minute!)
    }
    
    var snoozeUntilTomorrowInfo: (hhMm: HoursAndMinutes, includeWeekends: Bool) {
        (getHhMm(for: dayStartTimePicker), daysIncludeWeekends.state == .on)
    }
    
    //------------------------------------------------------------------
    // ABOUT
    //------------------------------------------------------------------
    
    @IBOutlet var shortVersion: NSTextField!
    @IBOutlet var copyright: NSTextField!
    @IBOutlet var fullVersion: NSTextField!
    @IBOutlet var shaVersion: NSButton!
    
    private func setUpAboutPanel() {
        shortVersion.stringValue = shortVersion.stringValue.replacingBracketedPlaceholders(with: [
            "version": Version.short
        ])
        copyright.stringValue = copyright.stringValue.replacingBracketedPlaceholders(with: [
            "copyright": Version.copyright
        ])
        fullVersion.stringValue = fullVersion.stringValue.replacingBracketedPlaceholders(with: [
            "fullversion": Version.full
        ])
        shaVersion.title = shaVersion.title.replacingBracketedPlaceholders(with: [
            "sha": Version.gitSha
        ])
        shaVersion.toolTip = shaVersion.toolTip?.replacingBracketedPlaceholders(with: [
            "sha": Version.gitSha.replacingOccurrences(of: ".dirty", with: "")
        ])
    }
    
    
    //------------------------------------------------------------------
    // OTHER / COMMON
    //------------------------------------------------------------------
    
    /// turns a button into an <a href>, with the link coming from the button's tooltip. Hacky, but easy. :-)
    @IBAction func href(_ sender: NSButton) {
        if let location = sender.toolTip, let url = URL(string: location) {
            NSWorkspace.shared.open(url)
        } else {
            NSLog("invalid href: \(sender.toolTip ?? "<nil>")")
        }
    }
    
}
