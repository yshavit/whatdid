import Cocoa

class TaskAdditionViewController: NSViewController {
    
    @IBOutlet weak var projectField: AutoCompletingComboBox!
    @IBOutlet weak var taskField: AutoCompletingComboBox!
    @IBOutlet weak var noteField: NSComboBox!
    @IBOutlet weak var breakButton: NSButton!
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
    
    override func flagsChanged(with event: NSEvent) {
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
