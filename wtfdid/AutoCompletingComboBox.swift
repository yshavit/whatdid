//
//  AutoCompletingComboBox.swift
//  wtfdid
//
//  Created by Yuval Shavit on 7/19/20.
//  Copyright © 2020 Yuval Shavit. All rights reserved.
//

import Cocoa

class AutoCompletingComboBox: NSComboBox, NSComboBoxDelegate {

    override func awakeFromNib() {
        print("combo is awake")
        self.delegate = self
    }
    
    var isAutoCompleting = false
    
    override func textDidChange(_ notification: Notification) {
        if isAutoCompleting {
            print("<<< END")
            isAutoCompleting = false
        } else {
            print("<<< START")
            isAutoCompleting = true
            updateSuggestions()
            super.textDidChange(notification)
        }
    }
    
    private func updateSuggestions() {
        let projects = AppDelegate.instance.model.listProjectsByPrefix(stringValue)
        print("text is now: \(stringValue); projects=\(projects)")
        removeAllItems()
        addItems(withObjectValues: projects)
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        updateSuggestions()
        cell?.setAccessibilityExpanded(true)
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        cell?.setAccessibilityExpanded(false)
        print("done editing")
    }
}
