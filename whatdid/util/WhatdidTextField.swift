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
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        let frameHeight = frame.height
        let _ = stringValue // makes sure intrinsicHeightIncludingWrapping uses the up-to-date text
        if let desiredHeight = intrinsicHeightIncludingWrapping, desiredHeight != frameHeight {
            invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize: NSSize {
        get {
            var superAdjusted = super.intrinsicContentSize
            if let adjustedHeight = intrinsicHeightIncludingWrapping {
                superAdjusted.height = adjustedHeight
            }
            return superAdjusted
        }
    }
    
    private var intrinsicHeightIncludingWrapping: CGFloat? {
        guard let cell = self.cell, let screen = window?.screen else {
            return nil
        }
        // I'm not sure why we need to shrink the width, but without it, the
        // field wraps one char later than it should.
        let widthShrink: CGFloat = isEditable ? 4.0 : 0.0
        let tallBounds = NSRect(
            x: bounds.minX,
            y: bounds.minX,
            width: bounds.width - widthShrink,
            height: screen.frame.height)
        let adjustedHeight = cell.cellSize(forBounds: tallBounds)
        return adjustedHeight.height
    }
}
