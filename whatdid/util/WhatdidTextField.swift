// whatdid?

import Cocoa

class WhatdidTextField: NSTextField {
    private var requestedWidth: CGFloat?

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
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        requestNewSize(newSize)
    }
    
    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        requestNewSize(newSize)
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
    
    private func requestNewSize(_ newSize: NSSize) {
        if requestedWidth != newSize.width {
            requestedWidth = newSize.width
            invalidateIntrinsicContentSize()
        }
    }
    
    private var intrinsicHeightIncludingWrapping: CGFloat? {
        guard let cell = self.cell, let screen = window?.screen else {
            return nil
        }
        // I'm not sure why we need to shrink the width, but without it, the
        // field wraps one char later than it should.
        let widthShrink: CGFloat = isEditable ? 4.0 : 0.0
        let myBounds = bounds
        let myWidth = requestedWidth ?? myBounds.width
        let tallBounds = NSRect(
            x: myBounds.minX,
            y: myBounds.minY,
            width: myWidth - widthShrink,
            height: screen.frame.height)
        let adjustedHeight = cell.cellSize(forBounds: tallBounds)
        return adjustedHeight.height
    }
}
