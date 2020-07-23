//
//  AutoCompletingComboBox.swift
//  wtfdid
//
//  Created by Yuval Shavit on 7/19/20.
//  Copyright © 2020 Yuval Shavit. All rights reserved.
//

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
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        updateSuggestions()
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        updateSuggestions()
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        cell?.setAccessibilityExpanded(false)
    }
    
    private func updateSuggestions() {
        removeAllItems()
        addItems(withObjectValues: lookups(stringValue))
        if numberOfItems > 0 {
            cell?.setAccessibilityExpanded(true)
        }
    }
}
