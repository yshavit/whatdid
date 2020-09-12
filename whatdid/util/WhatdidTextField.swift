// whatdid?

import Cocoa

class WhatdidTextField: NSTextField {

    override func becomeFirstResponder() -> Bool {
        let superSaysYes = super.becomeFirstResponder()
        if superSaysYes, let editor = currentEditor() {
            editor.perform(#selector(selectAll(_:)), with: self, afterDelay: 0)
        }
        return superSaysYes
    }
    
}
