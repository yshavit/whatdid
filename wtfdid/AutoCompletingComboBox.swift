import Cocoa

class AutoCompletingComboBox: NSComboBox, NSComboBoxDelegate {
    
    private var lookups : (String) -> [String] = {value in []}
    
    func setAutoCompleteLookups(_ lookups : @escaping (String) -> [String]) {
        self.lookups = lookups
    }

    override func awakeFromNib() {
        self.delegate = self
    }
    
    var isAutoCompleting = false
    
    override func becomeFirstResponder() -> Bool {
        updateSuggestions()
        if indexOfSelectedItem < 0 && numberOfItems > 0 {
            selectItem(at: 0)
        }
        return super.becomeFirstResponder()
    }
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        updateSuggestions()
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        let isBacktab = notification.userInfo?["NSTextMovement"] as? Int == NSTextMovement.backtab.rawValue
        if !isBacktab {
            cell?.setAccessibilityExpanded(false)
            nextKeyView?.becomeFirstResponder()
        }
    }
    
    private func updateSuggestions() {
        removeAllItems()
        addItems(withObjectValues: lookups(stringValue))
        cell?.setAccessibilityExpanded(numberOfItems > 0)
    }
}
