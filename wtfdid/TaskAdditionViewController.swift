import Cocoa

class TaskAdditionViewController: NSViewController {
    
    @IBOutlet weak var projectField: NSTextField!
    @IBOutlet weak var taskField: NSTextField!
    @IBOutlet weak var noteField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for field in [projectField, taskField, noteField] {
            if let plainString = field?.placeholderString {
                field?.placeholderAttributedString = NSAttributedString(
                    string: plainString,
                    attributes: [.foregroundColor: NSColor.secondarySelectedControlColor])
            }
        }
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
        
        AppDelegate.instance.model.addEntry(
            project: projectField.stringValue,
            task: taskField.stringValue,
            notes: noteField.stringValue,
            now: Date(),
            callback: {(maybeError) in
                AppDelegate.instance.model.printAll()
                AppDelegate.instance.hideMenu()
            }
        )
    }
    
    @IBAction func projectOrTaskEnter(_ sender: NSTextField) {
        sender.nextKeyView?.becomeFirstResponder()
    }
    
}
