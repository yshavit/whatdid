// whatdid?

import Cocoa

class AutoCompletingComboBox: NSComboBox, NSComboBoxDelegate {
    
    private var lookups : (String) -> [String] = {value in []}
    
    func setAutoCompleteLookups(_ lookups : @escaping (String) -> [String]) {
        self.lookups = lookups
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.delegate = self
        completes = true
    }

    override func becomeFirstResponder() -> Bool {
        updateSuggestions()
        return super.becomeFirstResponder()
    }
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        updateSuggestions()
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        let textMovement = notification.userInfo?["NSTextMovement"] as? Int
        let isEitherTab = textMovement == NSTextMovement.tab.rawValue || textMovement == NSTextMovement.backtab.rawValue
        if !isEitherTab {
            cell?.setAccessibilityExpanded(false)
            nextValidKeyView?.becomeFirstResponder()
        }
    }
    
    private func updateSuggestions() {
        removeAllItems()
        addItems(withObjectValues: lookups(stringValue))
        cell?.setAccessibilityExpanded(numberOfItems > 0)
    }
}
