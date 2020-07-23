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
        if isAutoCompleting {
            print("<<< END")
            isAutoCompleting = false
        } else {
            print("<<< START")
            isAutoCompleting = true
            updateSuggestions()
        }
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        print("cell: \(cell)")
        updateSuggestions()
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        cell?.setAccessibilityExpanded(false)
        print("done editing")
    }
    
    private func updateSuggestions() {
        let autocompletes = lookups(stringValue)
        print("text is now: \(stringValue); projects=\(autocompletes)")
        removeAllItems()
        addItems(withObjectValues: autocompletes)
        if autocompletes.count > 0 {
            cell?.setAccessibilityExpanded(true)
        }
    }
}
