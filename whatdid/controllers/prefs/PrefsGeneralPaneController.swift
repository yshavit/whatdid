//
//  PrefsGeneralPaneController.swift
//  whatdid
//
//  Created by Yuval Shavit on 10/9/23.
//  Copyright © 2023 Yuval Shavit. All rights reserved.
//

import Cocoa
import KeyboardShortcuts

class PrefsGeneralPaneController: NSViewController {
    
    @IBOutlet var dayStartTimePicker: NSDatePicker!
    @IBOutlet var daysIncludeWeekends: NSButton!
    
    @IBOutlet var dailyReportTime: NSDatePicker!
    
    @IBOutlet var globalShortcutHolder: NSView!
    
    @IBOutlet weak var exportFormatPopup: NSPopUpButton!
    
    let calendarForDateTimePickers = DefaultScheduler.instance.calendar
    
    // Hooks invoked by owning sheet:
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
    
    @IBInspectable
    dynamic var requireNotes: Bool {
        get { Prefs.requireNotes }
        set(value) { Prefs.requireNotes = value}
    }
    
    override func viewDidLoad() {
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
            wdlog(.debug, "Converting DateComponents to Date: %{public}@", dateComponents.description)
            if let date = dateComponents.date {
                picker.dateValue = date
            } else {
                wdlog(.warn, "Couldn't convert DateComponents to Date: %{public}@", dateComponents.description)
            }
        }
        setTimePicker(dailyReportTime, to: Prefs.dailyReportTime)
        setTimePicker(dayStartTimePicker, to: Prefs.dayStartTime)
        daysIncludeWeekends.state = Prefs.daysIncludeWeekends ? .on : .off
        
        exportFormatPopup.removeAllItems()
        allEntryExportFormats.forEach { format in
            exportFormatPopup.addItem(withTitle: format.name)
            exportFormatPopup.lastItem?.representedObject = format
        }
    }
    
    override func viewDidDisappear() {
        // Set the new daily report time, and reschedule it (it's fine if it's unchanged)
        Prefs.dailyReportTime = getHhMm(for: dailyReportTime)
        AppDelegate.instance.mainMenu.schedule(.dailyEnd)
        
        // Also reschedule the start-of-day prompt
        let snoozeInfo = snoozeUntilTomorrowInfo
        Prefs.dayStartTime = snoozeInfo.hhMm
        Prefs.daysIncludeWeekends = snoozeInfo.includeWeekends
        AppDelegate.instance.mainMenu.schedule(.dayStart)
    }
    
    static func exportFileName(_ format: EntryExportFormat, _ scheduler: Scheduler) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = scheduler.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HHmmssZ"
        let now = dateFormatter.string(from: scheduler.now)
        return "whatdid-export-\(now).\(format.fileExtension)"
    }
    
    func getHhMm(for picker: NSDatePicker) -> HoursAndMinutes {
        let components = calendarForDateTimePickers.dateComponents([.hour, .minute], from: picker.dateValue)
        return HoursAndMinutes(hours: components.hour!, minutes: components.minute!)
    }

    var snoozeUntilTomorrowInfo: (hhMm: HoursAndMinutes, includeWeekends: Bool) {
        (getHhMm(for: dayStartTimePicker), daysIncludeWeekends.state == .on)
    }
    
    @IBAction func handlePressExport(_ sender: Any) {
        let selectedFormat = exportFormatPopup.selectedItem
        guard let format = selectedFormat?.representedObject as? EntryExportFormat else {
            wdlog(.error, "Couldn't determine file format to export as")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export Whatdid Data"
        savePanel.nameFieldStringValue = PrefsGeneralPaneController.exportFileName(format, DefaultScheduler.instance)
        
        // The NSSavePanel won't have a window controller until we call begin, but we need to
        // increment the counter right away (or else the app will hide as soon as we end the sheet).
        // So, create a dummy controller just to "hold the spot" as it were.
        let dummyController = NSWindowController()
        AppDelegate.instance.windowOpened(dummyController)
        
        if let myWindow = view.window, let mySheetParent = myWindow.sheetParent {
            mySheetParent.endSheet(myWindow, returnCode: PrefsViewController.CLOSE_PTN)
        }
        
        savePanel.begin { response in
            defer {
                AppDelegate.instance.windowClosed(dummyController)
            }
            guard response == .OK else {
                return
            }
            guard let url = savePanel.url else {
                wdlog(.error, "couldn't find URL from save panel")
                return
            }
            guard let output = OutputStream(url: url, append: false) else {
                wdlog(.error, "couldn't open output stream for url=%@", savePanel.url?.path ?? "<unknown path>")
                return
            }
            wdlog(.debug, "export: fetching projects")
            let entries = AppDelegate.instance.model.listEntries(from: Date.distantPast, to: Date.distantFuture)
            
            wdlog(.debug, "preparing to write to stream")
            output.open()
            do {
                try format.write(entries: entries, to: output)
                wdlog(.info, "finished export to %@", url.path)
            } catch {
                wdlog(.error, "failed to export to %@: %@", url.path, error.localizedDescription)
            }
            output.close()
        }
    }
}
