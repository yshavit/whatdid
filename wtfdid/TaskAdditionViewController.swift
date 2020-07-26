import Cocoa

class TaskAdditionViewController: NSViewController {
    
    @IBOutlet weak var projectField: AutoCompletingComboBox!
    @IBOutlet weak var taskField: AutoCompletingComboBox!
    @IBOutlet weak var noteField: NSComboBox!
    @IBOutlet weak var breakButton: NSButton!
    @IBOutlet weak var snoozeButton: NSPopUpButton!
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
        let numberOfOptions = 4
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        
        var snoozeUntil = Date().addingTimeInterval(TimeInterval(bufferMinutes * 60))
        // Round it up (always up) to the nearest half-hour
        let incrementInterval = Double(30 * 60.0)
        snoozeUntil = Date(timeIntervalSince1970: (snoozeUntil.timeIntervalSince1970 / incrementInterval).rounded(.up) * incrementInterval)
        
        //let clock1 : Character = "\u{}"
        let clock1 = 0x1F550
        let clockHalfHour = 0xC
        
        snoozeButton.removeAllItems()
        for _ in 0..<numberOfOptions {
            var hourComponent = Calendar.current.component(.hour, from: snoozeUntil)
            if hourComponent == 0 {
                hourComponent = 12
            } else if hourComponent > 12 {
                hourComponent -= 12
            }
            // clock1 is 1-based, so if the hour component is 1, we need to add 0
            var clockCodePoint = clock1 + hourComponent - 1
            if Calendar.current.component(.minute, from: snoozeUntil) > 0 {
                clockCodePoint += clockHalfHour
            }
            var clockDescription = formatter.string(from: snoozeUntil)
            if let clockChar = UnicodeScalar(clockCodePoint)?.description {
                clockDescription += " \(clockChar)"
            }
            snoozeButton.addItem(withTitle: clockDescription)
            if let item = snoozeButton.item(at: snoozeButton.itemTitles.count - 1) {
                item.representedObject = Date(timeIntervalSince1970: snoozeUntil.timeIntervalSince1970)
            }
            
            snoozeUntil.addTimeInterval(incrementInterval)
        }
    }
    
    @IBAction func snoozeButtonPressed(_ sender: NSPopUpButton) {
        let snoozeUntilDate = sender.selectedItem?.representedObject
        print(snoozeUntilDate)
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
