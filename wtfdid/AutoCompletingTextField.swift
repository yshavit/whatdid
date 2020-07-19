import Cocoa

class AutoCompletingTextField: NSTextField, NSTextFieldDelegate {
    
    private var isAutoCompleting = false // prevents infinite loops
    
    override func awakeFromNib() {
        self.delegate = self
    }
    
    override func textDidChange(_ notification: Notification) {
        if isAutoCompleting {
            print("<<<<<< END AUTO COMPLETING")
            print()
            isAutoCompleting = false // this change came from the autocomplete
        } else {
            print(">>>>>> START AUTO COMPLETING")
            // Mark us as autocompleting, so we don't spin into an infinite loop
            isAutoCompleting = true
            currentEditor()?.complete(self)
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        let res = ["one"]
        print("control")
        print(" - given:     \(words)")
        print(" - returning: \(res)")
        return res
    }
}
