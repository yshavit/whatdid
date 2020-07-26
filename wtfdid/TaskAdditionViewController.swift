import Cocoa

class TaskAdditionViewController: NSViewController {
    
    @IBOutlet weak var projectField: AutoCompletingComboBox!
    @IBOutlet weak var taskField: AutoCompletingComboBox!
    @IBOutlet weak var noteField: NSComboBox!
    @IBOutlet weak var breakButton: NSButton!
    
    @IBOutlet weak var snoozeButton: NSButton!
    private var snoozeUntil : Date?
    @IBOutlet weak var snoozeExtraOptions: NSPopUpButton!
    
    private var optionIsPressed = false
    
    var closeAction : () -> Void = {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for field in [projectField, taskField, noteField] {
            if let plainString = field?.placeholderString {
                field?.placeholderAttributedString = NSAttributedString(
                    string: plainString,
                    attributes: [.foregroundColor: NSColor.secondarySelectedControlColor])
            }
        }
        projectField.setAutoCompleteLookups({prefix in AppDelegate.instance.model.listProjects(prefix: prefix)})
        taskField.setAutoCompleteLookups({prefix in AppDelegate.instance.model.listTasks(project: self.self.projectField.stringValue, prefix: prefix)})
        setBreakButtonTitle()
    }
    
    func setBreakButtonTitle() {
        let optionsToDisplay = breakButton.keyEquivalentModifierMask.subtracting(.option)
        let combo = AppDelegate.keyComboString(keyEquivalent: breakButton.keyEquivalent, keyEquivalentMask: optionsToDisplay)
        let name = optionIsPressed ? "Skip this session" : "Break"
        breakButton.title = combo.isEmpty ? name : "\(name) (\(combo))"
    }
    
    func reset() {
        noteField.stringValue = ""
        if projectField.stringValue.isEmpty {
            taskField.stringValue = ""
        }
    }
    
    override func viewWillAppear() {
        // Set up the snooze button. We'll have 4 options at half-hour increments, starting 10 minutes from now.
        // The 10 minutes is so that if it's currently 2:29:59, you won't be annoyed with a "snooze until 2:30" button.
        let bufferMinutes = 10
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        
        var snoozeUntil = Date().addingTimeInterval(TimeInterval(bufferMinutes * 60))
        // Round it up (always up) to the nearest half-hour
        let incrementInterval = Double(30 * 60.0)
        snoozeUntil = Date(timeIntervalSince1970: (snoozeUntil.timeIntervalSince1970 / incrementInterval).rounded(.up) * incrementInterval)

        snoozeButton.title = formatter.string(from: snoozeUntil) + "   " // extra space for the pulldown option
        self.snoozeUntil = Date(timeIntervalSince1970: snoozeUntil.timeIntervalSince1970)
        snoozeExtraOptions.itemArray[1...].forEach({menuItem in
            snoozeUntil.addTimeInterval(incrementInterval)
            menuItem.title = formatter.string(from: snoozeUntil)
            menuItem.representedObject = Date(timeIntervalSince1970: snoozeUntil.timeIntervalSince1970)
        })
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
            print("error: date not set up (was \(until ?? "nil"))")
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
        perform(#selector(grabFocusNow), with: nil, afterDelay: TimeInterval.zero, inModes: [RunLoop.Mode.common])
    }
    
    @objc private func grabFocusNow() {
        var firstResponder = noteField
        if projectField.stringValue.isEmpty {
            firstResponder = projectField
        } else if taskField.stringValue.isEmpty {
            firstResponder = taskField
        }
        firstResponder?.becomeFirstResponder()
    }
    
    @IBAction func notesFieldAction(_ sender: NSTextField) {
        AppDelegate.instance.model.addEntryNow(
            project: projectField.stringValue,
            task: taskField.stringValue,
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
    
    @IBAction func projectOrTaskEnter(_ sender: NSTextField) {
        sender.nextKeyView?.becomeFirstResponder()
    }
}
