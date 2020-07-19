import Cocoa

class AutoCompletingTextField: NSTextField, NSTextFieldDelegate {
    
    private var isAutoCompleting = false // prevents infinite loops
    var autoCompleteLookups : (String) -> [String] = {(current) in []}
    
    override func awakeFromNib() {
        self.delegate = self
    }
    
    override func textDidChange(_ notification: Notification) {
        if isAutoCompleting {
            print("<<<<<< END AUTO COMPLETING")
//            print()
            isAutoCompleting = false // this change came from the autocomplete
        } else {
            let currentEventChars = NSApp.currentEvent?.characters
            if currentEventChars?.contains("\u{7F}") ?? false {
                print("!!!!!! SKIPPING AUTO COMPLETING: \(currentEventChars)")
            } else {
                print(">>>>>> START AUTO COMPLETING: \(currentEventChars)")
                // Mark us as autocompleting, so we don't spin into an infinite loop
                
                isAutoCompleting = true
                currentEditor()?.complete(self)
            }
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        let value = NSString(string: textView.string)
        let stringToComplete = value.substring(with: charRange)
        let res = autoCompleteLookups(stringToComplete)
        print("control \"\(stringToComplete)\" from \"\(value)\"@\(charRange)")
//        print(" - given:     \(words)")
//        print("*** for \"\(stringToComplete)\" (\(charRange)), returning: \(res)")
        return res
    }
}
