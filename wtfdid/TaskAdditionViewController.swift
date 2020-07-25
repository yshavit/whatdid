import Cocoa

class TaskAdditionViewController: NSViewController {
    
    @IBOutlet weak var projectField: AutoCompletingComboBox!
    @IBOutlet weak var taskField: AutoCompletingComboBox!
    @IBOutlet weak var noteField: NSComboBox!
    @IBOutlet weak var breakButton: NSButton!
    
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
        let combo = AppDelegate.keyComboString(keyEquivalent: breakButton.keyEquivalent, keyEquivalentMask: breakButton.keyEquivalentModifierMask)
        breakButton.title = combo.isEmpty ? "Break" : "Break (\(combo))"
    }
    
    func reset() {
        noteField.stringValue = ""
        if projectField.stringValue.isEmpty {
            taskField.stringValue = ""
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
        AppDelegate.instance.model.addBreakEntry(
            callback: closeAction
        )
    }
    
    @IBAction func projectOrTaskEnter(_ sender: NSTextField) {
        sender.nextKeyView?.becomeFirstResponder()
    }
}
