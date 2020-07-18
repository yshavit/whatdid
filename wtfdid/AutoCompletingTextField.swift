import Cocoa

class AutoCompletingTextField: NSTextField, NSTextFieldDelegate {
    
    private var isAutoCompleting = false // prevents infinite loops
    
    var autoCompleteLookups : (String) -> [String] = {current in return []}
    
    override func awakeFromNib() {
        self.delegate = self
    }
    
    override func textDidChange(_ notification: Notification) {
        if isAutoCompleting {
            isAutoCompleting = false // this change came from the autocomplete
        } else {
            currentEditor()?.complete(self)
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        // TODO the "words" arg is being pre-populated from *somewhere*. Should I figure out where?
        return autoCompleteLookups(stringValue)
    }
}
