// whatdid?

import Cocoa

class PtnViewController: NSViewController {
    private static let TIME_UNTIL_NEW_SESSION_PROMPT = TimeInterval(6 * 60 * 60)
    @IBOutlet var topStack: NSStackView!
    
    @IBOutlet weak var projectField: AutoCompletingField!
    @IBOutlet weak var taskField: AutoCompletingField!
    @IBOutlet weak var noteField: NSTextField!
    @IBOutlet weak var breakButton: NSButton!
    
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
        setBreakButtonTitle()
        
        #if UI_TEST
        addJsonFlatEntryField()
        #endif
    }
    
    func setBreakButtonTitle() {
        let optionsToDisplay = breakButton.keyEquivalentModifierMask.subtracting(.option)
        let combo = AppDelegate.keyComboString(keyEquivalent: breakButton.keyEquivalent, keyEquivalentMask: optionsToDisplay)
        let name = optionIsPressed ? "Skip this session" : "Break"
        breakButton.title = combo.isEmpty ? name : "\(name) (\(combo))"
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
        
        if AppDelegate.instance.model.timeSinceLastEntry > PtnViewController.TIME_UNTIL_NEW_SESSION_PROMPT {
            showNewSessionPrompt()
        } else {
            scheduler.schedule(after: PtnViewController.TIME_UNTIL_NEW_SESSION_PROMPT, showNewSessionPrompt)
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        noteField.stringValue = ""
        
        // Set up the snooze button. We'll have 4 options at half-hour increments, starting 10 minutes from now.
        // The 10 minutes is so that if it's currently 2:29:59, you won't be annoyed with a "snooze until 2:30" button.
        let bufferMinutes = 10
        let formatter = DateFormatter()
        let snoozeIntervalMinutes = 30.0
        formatter.timeZone = scheduler.timeZone
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        
        var snoozeUntil = scheduler.now.addingTimeInterval(TimeInterval(bufferMinutes * 60))
        // Round it up (always up) to the nearest half-hour
        let incrementInterval = Double(snoozeIntervalMinutes * 60.0)
        snoozeUntil = Date(timeIntervalSince1970: (snoozeUntil.timeIntervalSince1970 / incrementInterval).rounded(.up) * incrementInterval)

        snoozeButton.title = "Snooze until \(formatter.string(from: snoozeUntil))   " // extra space for the pulldown option
        self.snoozeUntil = Date(timeIntervalSince1970: snoozeUntil.timeIntervalSince1970)
        snoozeExtraOptions.itemArray[1...].forEach({menuItem in
            snoozeUntil.addTimeInterval(incrementInterval)
            menuItem.title = formatter.string(from: snoozeUntil)
            menuItem.representedObject = Date(timeIntervalSince1970: snoozeUntil.timeIntervalSince1970)
        })
        
        #if UI_TEST
        populateJsonFlatEntryField()
        #endif
    }
    
    @IBAction private func snoozeButtonPressed(_ sender: NSControl) {
        snooze(until: snoozeUntil)
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
    
    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        let optionIsNowPressed = event.modifierFlags.contains(.option)
        if optionIsNowPressed != optionIsPressed {
            optionIsPressed = optionIsNowPressed
            if optionIsNowPressed {
                breakButton.keyEquivalentModifierMask.insert(.option)
            } else {
                breakButton.keyEquivalentModifierMask.remove(.option)
            }
            setBreakButtonTitle()
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
    
    @IBAction func breakButtonPressed(_ sender: Any) {
        if optionIsPressed {
            AppDelegate.instance.model.setLastEntryDateToNow()
            closeAction()
        } else {
            AppDelegate.instance.model.addBreakEntry(
                callback: closeAction
            )
        }
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
