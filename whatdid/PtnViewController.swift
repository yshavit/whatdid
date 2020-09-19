// whatdid?

import Cocoa

class PtnViewController: NSViewController {
    private static let TIME_UNTIL_NEW_SESSION_PROMPT = TimeInterval(6 * 60 * 60)
    @IBOutlet var topStack: NSStackView!
    
    @IBOutlet var headerText: NSTextField!
    
    @IBOutlet weak var projectField: AutoCompletingField!
    @IBOutlet weak var taskField: AutoCompletingField!
    @IBOutlet weak var noteField: NSTextField!
    @IBOutlet weak var skipButton: NSButton!
    
    @IBOutlet weak var snoozeButton: NSButton!
    private var snoozeUntil : Date?
    @IBOutlet weak var snoozeExtraOptions: NSPopUpButton!
    
    private var optionIsPressed = false
    
    var closeAction : () -> Void = {}
    
    var scheduler: Scheduler = DefaultScheduler.instance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        projectField.textField.placeholderString = "project"
        taskField.textField.placeholderString = "task"
        for field in [projectField.textField, taskField.textField, noteField] {
            if let plainString = field?.placeholderString {
                field?.placeholderAttributedString = NSAttributedString(
                    string: plainString,
                    attributes: [.foregroundColor: NSColor.secondarySelectedControlColor])
            }
        }
        projectField.optionsLookupOnFocus = {
            AppDelegate.instance.model.listProjects(prefix: "")
        }
        taskField.optionsLookupOnFocus = {
            AppDelegate.instance.model.listTasks(project: self.projectField.textField.stringValue, prefix: "")
        }
        projectField.onTextChange = {
            self.taskField.textField.stringValue = ""
        }
        projectField.action = self.projectOrTaskAction
        taskField.action = self.projectOrTaskAction
        
        headerText.placeholderString = headerText.stringValue
        
        #if UI_TEST
        addJsonFlatEntryField()
        #endif
    }
    
    func reset() {
        noteField.stringValue = ""
        if projectField.textField.stringValue.isEmpty {
            taskField.textField.stringValue = ""
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        projectField.nextKeyView = taskField
        taskField.nextKeyView = noteField
        noteField.nextKeyView = projectField
        
        if timeInterval(since: AppDelegate.instance.model.lastEntryDate) > PtnViewController.TIME_UNTIL_NEW_SESSION_PROMPT {
            showNewSessionPrompt()
        } else {
            scheduler.schedule("new session prompt", after: PtnViewController.TIME_UNTIL_NEW_SESSION_PROMPT, showNewSessionPrompt)
        }

        func scheduleUpdateHeaderText() {
            scheduler.schedule("per-minute update header", after: 60) {
                self.updateHeaderText()
                scheduleUpdateHeaderText()
            }
        }
        scheduleUpdateHeaderText()
    }
    
    private func timeInterval(since date: Date) -> TimeInterval {
        return scheduler.now.timeIntervalSince(date)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        noteField.stringValue = ""
        setUpSnoozeButton()
        updateHeaderText()
    }
    
    private func setUpSnoozeButton() {
        if let alreadySnoozedUntil = AppDelegate.instance.snoozedUntil {
            snoozeButton.title = "Snoozing until \(TimeUtil.formatSuccinctly(date: alreadySnoozedUntil))..."
            snoozeExtraOptions.isEnabled = false
        } else {
            // Set up the snooze button. We'll have 4 options at half-hour increments, starting 10 minutes from now.
            // The 10 minutes is so that if it's currently 2:29:59, you won't be annoyed with a "snooze until 2:30" button.
            let bufferMinutes = 10
            let snoozeIntervalMinutes = 30.0
            
            let now = scheduler.now
            var snoozeUntil = now.addingTimeInterval(TimeInterval(bufferMinutes * 60))
            // Round it up (always up) to the nearest half-hour
            let incrementInterval = Double(snoozeIntervalMinutes * 60.0)
            snoozeUntil = Date(timeIntervalSince1970: (snoozeUntil.timeIntervalSince1970 / incrementInterval).rounded(.up) * incrementInterval)

            snoozeButton.title = "Snooze until \(TimeUtil.formatSuccinctly(date: snoozeUntil))   " // extra space for the pulldown option
            self.snoozeUntil = Date(timeIntervalSince1970: snoozeUntil.timeIntervalSince1970)
            var latestDate = snoozeUntil
            snoozeExtraOptions.isEnabled = true
            for menuItem in snoozeExtraOptions.itemArray[1...] {
                if menuItem.isSeparatorItem {
                    break
                }
                snoozeUntil.addTimeInterval(incrementInterval)
                menuItem.title = TimeUtil.formatSuccinctly(date: snoozeUntil)
                latestDate = Date(timeIntervalSince1970: snoozeUntil.timeIntervalSince1970)
                menuItem.representedObject = latestDate
            }
            let nextSessionDate = TimeUtil.dateForTime(.next, hh: 9, mm: 00, excludeWeekends: true, assumingNow: latestDate)
            if let nextSessionItem = snoozeExtraOptions.lastItem {
                nextSessionItem.title = TimeUtil.formatSuccinctly(date: nextSessionDate)
                nextSessionItem.representedObject = nextSessionDate
            }
        }
        
        #if UI_TEST
        populateJsonFlatEntryField()
        #endif
    }
    
    private func updateHeaderText() {
        let lastEntryDate = AppDelegate.instance.model.lastEntryDate
        headerText.stringValue = headerText.placeholderString!
            .replacingOccurrences(of: "{TIME}", with: TimeUtil.formatSuccinctly(date: lastEntryDate))
            .replacingOccurrences(of: "{DURATION}", with: TimeUtil.daysHoursMinutes(for: timeInterval(since: lastEntryDate)))
    }
    
    @IBAction private func snoozeButtonPressed(_ sender: NSControl) {
        if let _ = AppDelegate.instance.snoozedUntil {
            let unsnoozePopover = NSPopover()
            unsnoozePopover.behavior = .transient
            
            let unsnoozeViewController = NSViewController()
            let button = ButtonWithClosure(label: "Unsnooze") {_ in
                AppDelegate.instance.unSnooze()
                self.setUpSnoozeButton()
                unsnoozePopover.close()
            }
            button.font = snoozeButton.font
            button.focusRingType = .none
            button.bezelStyle = .roundRect
            button.bezelColor = NSColor.controlAccentColor
            button.contentTintColor = NSColor.controlAccentColor
            
            unsnoozeViewController.view = button
            let buttonSize = button.intrinsicContentSize
            unsnoozePopover.contentSize = NSSize(width: buttonSize.width * 1.4, height: buttonSize.height * 1.5)
            
            unsnoozePopover.contentViewController = unsnoozeViewController
            unsnoozePopover.show(relativeTo: snoozeButton.bounds, of: snoozeButton, preferredEdge: .minY)
        } else {
            snooze(until: snoozeUntil)
        }
    }
    
    @IBAction func snoozeExtraOptionsSelected(_ sender: NSPopUpButton) {
        snooze(until: sender.selectedItem?.representedObject)
    }
    
    private func snooze(until: Any?) {
        if let date = until as? Date {
            AppDelegate.instance.snooze(until: date)
        } else {
            NSLog("error: date not set up (was \(until ?? "nil"))")
        }
    }
    
    @IBAction func preferenceButtonPressed(_ sender: NSButton) {
        if let viewWindow = view.window {
            let prefsWindow = NSPanel(contentRect: viewWindow.frame, styleMask: [.titled], backing: .buffered, defer: true)
//            prefsWindow.toolbar = NSToolbar(identifier: "foo")
            prefsWindow.toolbar?.insertItem(withItemIdentifier: NSToolbarItem.Identifier(rawValue: "Foo"), at: 0)
            prefsWindow.backgroundColor = NSColor.windowBackgroundColor
            
            let prefsViewController = PrefsViewController(nibName: "PrefsViewController", bundle: nil)
            prefsViewController.setSize(width: viewWindow.frame.width, minHeight: viewWindow.frame.height)
            prefsWindow.contentViewController = prefsViewController
            
//            let prefsMainStack = NSStackView(orientation: .vertical)
//            prefsMainStack.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
//            prefsMainStack.alignment = .left
//            prefsWindow.contentView = prefsMainStack
//
//            let doneOrCancelRow = NSStackView(orientation: .horizontal)
//
//            func button(label: String, enabled: Bool = true, endSheetWith response: NSApplication.ModalResponse) -> NSControl {
//                let result = ButtonWithClosure(label: label, {_ in
//                    viewWindow.endSheet(prefsWindow, returnCode: response)
//                })
//                result.bezelStyle = .roundRect
//                result.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
//                if !enabled {
//                    result.isEnabled = false
//                }
//                return result
//            }
//
//            doneOrCancelRow.addArrangedSubview(button(label: "Quit", endSheetWith: .stop))
//            doneOrCancelRow.addArrangedSubview(NSView())
//            doneOrCancelRow.addArrangedSubview(button(label: "Cancel", endSheetWith: .cancel))
//            doneOrCancelRow.addArrangedSubview(button(label: "Save", enabled: false, endSheetWith: .OK))
//            prefsMainStack.addArrangedSubview(doneOrCancelRow)
            viewWindow.beginSheet(prefsWindow, completionHandler: {reason in
                if reason == .stop {
                    NSApp.terminate(self)
                }
                print("Dismissing for reason code=\(reason.rawValue)")
            })
        }
    }
    
    func grabFocus() {
        if (view.window?.sheets ?? []).isEmpty {
            grabFocusEvenIfHasSheet()
        }
    }
    
    private func grabFocusEvenIfHasSheet() {
        perform(#selector(grabFocusNow), with: nil, afterDelay: TimeInterval.zero, inModes: [RunLoop.Mode.common])
    }
    
    @objc private func grabFocusNow() {
        var firstResponder = noteField
        if projectField.textField.stringValue.isEmpty {
            firstResponder = projectField.textField
        } else if taskField.textField.stringValue.isEmpty {
            firstResponder = taskField.textField
        }
        firstResponder?.becomeFirstResponder()
    }
    
    func projectOrTaskAction(_ sender: AutoCompletingField) {
        if let nextView = sender.nextValidKeyView {
            view.window?.makeFirstResponder(nextView)
        }
    }
    
    @IBAction func notesFieldAction(_ sender: NSTextField) {
        AppDelegate.instance.model.addEntryNow(
            project: projectField.textField.stringValue,
            task: taskField.textField.stringValue,
            notes: noteField.stringValue,
            callback: closeAction
        )
    }
    
    @IBAction func skipButtonPressed(_ sender: Any) {
        AppDelegate.instance.model.setLastEntryDateToNow()
        closeAction()
    }
    
    override func viewWillDisappear() {
        if let window = view.window {
            for sheet in window.sheets {
                window.endSheet(sheet, returnCode: .abort)
            }
        }
        super.viewWillDisappear()
    }
    
    private func showNewSessionPrompt() {
        if let window = view.window {
            
            let sheet = NSWindow(contentRect: window.contentView!.frame, styleMask: [], backing: .buffered, defer: true)
            let mainStack = NSStackView()
            mainStack.orientation = .vertical
            mainStack.useAutoLayout()
            mainStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            sheet.contentView = mainStack
            
            let headerLabel = NSTextField(labelWithString: "It's been a while since you last checked in.")
            headerLabel.font = NSFont.boldSystemFont(ofSize: NSFont.labelFontSize * 1.25)
            mainStack.addArrangedSubview(headerLabel)
            
            let optionsStack = NSStackView()
            optionsStack.useAutoLayout()
            mainStack.addArrangedSubview(optionsStack)
            optionsStack.orientation = .horizontal
            optionsStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
            optionsStack.addView(
                ButtonWithClosure(label: "Start new session") {_ in
                    window.endSheet(sheet, returnCode: .OK)
                },
                in: .center)
            optionsStack.addView(
                ButtonWithClosure(label: "Continue with current session") {_ in
                    window.endSheet(sheet, returnCode: .continue)
                },
            in: .center)
            
            window.makeFirstResponder(nil)
            window.beginSheet(sheet) {response in
                let startNewSession: Bool
                switch(response) {
                case .OK:
                    NSLog("Starting new session")
                    startNewSession = true
                case .continue:
                    NSLog("Continuing with existing session")
                    startNewSession = false
                case .abort:
                    NSLog("Aborting window (probably because user closed it via status menu item)")
                    startNewSession = false
                default:
                    NSLog("Unexpected response: \(response.rawValue). Will start new session session.")
                    startNewSession = false
                }
                if startNewSession {
                    AppDelegate.instance.model.setLastEntryDateToNow()
                    self.closeAction()
                } else {
                    self.grabFocusEvenIfHasSheet()
                }
            }
        }
    }
}
