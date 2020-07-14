import Cocoa

class TaskAdditionViewController: NSViewController {
    
    @IBOutlet weak var projectField: NSTextField!
    @IBOutlet weak var taskField: NSTextField!
    @IBOutlet weak var noteField: NSTextField!
    
    func grabFocus() {
        perform(#selector(grabFocusNow), with: nil, afterDelay: TimeInterval.zero, inModes: [RunLoop.Mode.common])
    }
    
    @objc private func grabFocusNow() {
        projectField.becomeFirstResponder()
    }
}
