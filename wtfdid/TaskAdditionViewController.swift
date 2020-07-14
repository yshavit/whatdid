import Cocoa

class TaskAdditionViewController: NSViewController {
    
    @IBOutlet weak var projectField: NSTextField!
    @IBOutlet weak var taskField: NSTextField!
    @IBOutlet weak var noteField: NSTextField!
    
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
        var firstResponder = projectField
        if projectField.stringValue.isEmpty {
            firstResponder = projectField
        } else if taskField.stringValue.isEmpty {
            firstResponder = taskField
        }
        firstResponder?.becomeFirstResponder()
    }
}
