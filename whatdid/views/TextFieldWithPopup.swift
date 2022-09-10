// whatdid?

import Cocoa

class TextFieldWithPopup: WhatdidTextField, NSTextViewDelegate, NSTextFieldDelegate {
    // Invoked when the text changes
    var onTextChange: (() -> Void) = {}
    // Invoked when the user escapes out of the field.
    var onCancel: (() -> Void) = {}
    
    fileprivate var pulldownButton: NSButton!
    
    private var previousAutocompleteHeadLength = 0
    private var shouldAutocompleteOnTextChange = false
    private var popupManager: PopupManager!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    var contents: TextFieldWithPopupContents? {
        get {
            popupManager.contents
        } set(c) {
            popupManager.contents = c
        }
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        adjustPopupLocation()
    }
    
    fileprivate func adjustPopupLocation() {
        if popupManager.window.isVisible, let window = window {
            let popup = popupManager.window
            guard window.screen == popup.screen else {
                // Popup screen may be nil if the popup's size is zero. Otherwise, they should be on the
                // same screen.
                if popup.screen != nil {
                    wdlog(.warn, "window screen and autocomplete popup screen were different")
                }
                return
            }
            let myBoundsWithinWindow = convert(bounds, to: nil)
            let myBoundsWithinScreen = window.convertToScreen(myBoundsWithinWindow)
            let myBottom = myBoundsWithinScreen.maxY - myBoundsWithinScreen.height
            let desiredWindowTop = myBottom - PopupManager.HEIGHT_FROM_BOTTOM_OF_FIELD
            if popup.frame.maxY != desiredWindowTop {
                popup.setFrameTopLeftPoint(NSPoint(x: popup.frame.minX, y: desiredWindowTop))
            }
        }
    }
    
    private func commonInit() {
        popupManager = PopupManager(parent: self)
        useAutoLayout()
        
        setAccessibilityRole(.textField)
        let textFieldCell = ShrunkenTextFieldCell(textCell: "")
        self.cell = textFieldCell
        self.isBordered = true
        self.backgroundColor = .white
        self.isBezeled = true
        self.bezelStyle = .squareBezel
        self.isEnabled = true
        self.isEditable = true
        self.isSelectable = true
        self.placeholderString = "placeholder"
        
        pulldownButton = NoKeyButton()
        pulldownButton.useAutoLayout()
        addSubview(pulldownButton)
        // button styling
        pulldownButton.imageScaling = .scaleProportionallyDown
        pulldownButton.bezelStyle = .smallSquare
        pulldownButton.state = .off
        pulldownButton.setButtonType(.momentaryPushIn)
        pulldownButton.imagePosition = .imageOnly
        pulldownButton.image = NSImage(named: NSImage.touchBarGoDownTemplateName)
        pulldownButton.setAccessibilityRole(.popUpButton)
        pulldownButton.setAccessibilityLabel("Toggle options")
        if let pulldownCell = pulldownButton.cell as? NSButtonCell {
            pulldownCell.isBordered = false
            pulldownCell.backgroundColor = .controlAccentColor
        }
        // button positioning
        pulldownButton.topAnchor.constraint(equalTo: topAnchor).isActive = true
        pulldownButton.heightAnchor.constraint(equalToConstant: textFieldCell.cellSize.height).isActive = true
        pulldownButton.widthAnchor.constraint(equalTo: pulldownButton.heightAnchor, multiplier: 0.75).isActive = true
        pulldownButton.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        textFieldCell.widthAdjustment = { self.pulldownButton.frame.width }
        // button behavior
        pulldownButton.target = self
        pulldownButton.action = #selector(self.buttonClicked)
        
        let pulldownButtonTracker = NSTrackingArea(
            rect: frame,
            options: [.inVisibleRect, .mouseMoved, .activeAlways],
            owner: self)
        addTrackingArea(pulldownButtonTracker)
        
        delegate = self
    }
    
    override func setAccessibilityIdentifier(_ id: String?) {
        super.setAccessibilityIdentifier(id)
        cell?.setAccessibilityIdentifier(id.map({ "\($0)__cell"}))
        pulldownButton.setAccessibilityIdentifier(id.map({ "\($0)__pulldown"}))
        #warning("TODO what here?")
//        popupManager.accessibilityIdentifierChanged()
    }
    
    /// Set the cursor to the arrow (instead of NSTextField's default I-beam) when hovering over the button
    override func mouseMoved(with event: NSEvent) {
        if pulldownButton.frame.contains(convert(event.locationInWindow, from: nil)) {
            NSCursor.arrow.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(moveDown(_:)):
            if !popupManager.window.isVisible {
                showOptions()
            }
            popupManager.contents?.moveSelection(.down)
            return true
        case #selector(moveUp(_:)):
            if !popupManager.window.isVisible {
                showOptions()
            }
            popupManager.contents?.moveSelection(.up)
            return true
        case #selector(cancelOperation(_:)):
            if popupManager.window.isVisible {
                popupManager.close()
            } else {
                onCancel()
            }
            return true
        default:
            break
        }
        // If we got here, we haven't explicitly handled the command. Find the next responder who will.
        // For reasons I don't understand, we can't just return "false" here and trust someone else to
        // find the next responder.
        var maybeResponder = nextResponder
        while let responder = maybeResponder {
            if responder.responds(to: commandSelector) {
                responder.doCommand(by: commandSelector)
                return true
            }
            maybeResponder = responder.nextResponder
        }
        return false
    }

    override func becomeFirstResponder() -> Bool {
        let succeeded = super.becomeFirstResponder()
        if succeeded {
            showOptions()
        }
        return succeeded
    }
    
    func textViewDidChangeSelection(_ notification: Notification) {
        let selectedRange = currentEditor()!.selectedRange
        let currentSelectionIsTail = selectedRange.location + selectedRange.length == stringValue.count
        if currentSelectionIsTail {
            let currentAutocompleteHeadLength = selectedRange.location
            shouldAutocompleteOnTextChange = currentAutocompleteHeadLength > previousAutocompleteHeadLength
            previousAutocompleteHeadLength = currentAutocompleteHeadLength
        } else {
            previousAutocompleteHeadLength = 0
            shouldAutocompleteOnTextChange = false
        }
    }
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        textDidChange()
    }
    
    private func textDidChange() {
        let maybeAutocomplete = popupManager.contents?.onTextChanged(to: stringValue)
        // If the selection is at the tail of the string, fill in the autocomplete.
        if shouldAutocompleteOnTextChange, let autoComplete = maybeAutocomplete, autoComplete.starts(with: stringValue) {
            let charsToAutocomplete = autoComplete.count - stringValue.count
            if charsToAutocomplete > 0 {
                let autocompleTail = String(autoComplete.dropFirst(stringValue.count))
                let stringCountBeforeAutocomplete = stringValue.count
                stringValue += autocompleTail
                currentEditor()!.selectedRange = NSRange(location: stringCountBeforeAutocomplete, length: charsToAutocomplete)
            }
        }
        onTextChange()
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        popupManager.close()
    }
    
    @objc private func buttonClicked() {
        if popupManager.window.isVisible {
            // Note: we shouldn't ever actually get here, but I'm putting it just in case.
            // That's because if the popup is open, any click outside of it (including to this button) will close it.
            wdlog(.warn, "Unexpectedly saw button press while options popup was open on %{public}@", idForLogging)
            popupManager.close()
        } else {
            if !(window?.makeFirstResponder(self) ?? false) {
                wdlog(.error, "Couldn't make first responder: %{public}@", idForLogging)
            }
            showOptions()
        }
    }
    
    private var idForLogging: String {
        return accessibilityLabel() ?? "unidentifed field at \(frame.debugDescription)"
    }
    
    func showOptions() {
        let originWithinWindow = superview!.convert(frame.origin, to: nil)
        let originWithinScreen = window!.convertPoint(toScreen: originWithinWindow)
        popupManager.show(
            minWidth: frame.width,
            atTopLeft: originWithinScreen)
        textDidChange()
    }
    
    private class NoKeyButton: NSButton {
        override var canBecomeKeyView: Bool {
            return false
        }
    }
}

/// An NSTextFieldCell with a smaller frame, to accommodate the popup button.
private class ShrunkenTextFieldCell: NSTextFieldCell {
    
    fileprivate var widthAdjustment: () -> CGFloat = { 0 }
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        return adjusted(super.drawingRect(forBounds: rect))
    }
    
    override func cellSize(forBounds rect: NSRect) -> NSSize {
        return super.cellSize(forBounds: adjusted(rect))
    }
    
    private func adjusted(_ r: NSRect) -> NSRect {
        return NSRect(x: r.minX, y: r.minY, width: r.width - widthAdjustment(), height: r.height)
    }
}

fileprivate class PopupManager: NSObject, NSWindowDelegate, TextFieldWithPopupCallbacks {
    static let HEIGHT_FROM_BOTTOM_OF_FIELD: CGFloat = 2
    static let GROUPING_LABEL_TAG = 1
    static let MAX_HEIGHT = 100.0
    
    fileprivate let window: NSPanel
    
    private let parent: TextFieldWithPopup
    private let scrollView: NSScrollView
    private let scrollViewWidth: NSLayoutConstraint
    private var activeEventMonitors = [Any?]()
    
    init(parent: TextFieldWithPopup) {
        self.parent = parent
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 0),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.hasShadow = true
        
        scrollView = NSScrollView()
        scrollView.useAutoLayout()
        scrollView.contentView.anchorAllSides(to: scrollView)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollViewWidth = scrollView.widthAnchor.constraint(equalToConstant: 100)
        scrollViewWidth.isActive = true
        scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: PopupManager.MAX_HEIGHT).isActive = true
        
        let flipped = FlippedView()
        flipped.useAutoLayout()
        scrollView.documentView = flipped
        
        window.contentView = scrollView
        window.level = .popUpMenu
        window.setAccessibilityChildren(nil)
        window.setAccessibilityRole(.none)
        
        super.init()
        window.delegate = self
    }
    
    var contents: TextFieldWithPopupContents? {
        didSet {
            let scrollDocView = scrollView.documentView as! FlippedView
            if let view = contents?.asView {
                scrollDocView.subviews = [view]
                view.anchorAllSides(to: scrollDocView)
            } else {
                scrollDocView.subviews = []
            }
        }
    }
    
    func close() {
        window.close()
        self.parent.adjustPopupLocation()
    }
    
    func show(minWidth: CGFloat, atTopLeft: CGPoint) {
        contents?.willShow(callbacks: self)
        guard !window.isVisible else {
            return
        }
        scrollViewWidth.constant = minWidth
        contentSizeChanged()
        var popupOrigin = atTopLeft
        popupOrigin.y -= (window.frame.height + PopupManager.HEIGHT_FROM_BOTTOM_OF_FIELD)
        window.setFrameOrigin(popupOrigin)
        window.display()
        window.setIsVisible(true)
        scrollView.setAccessibilityHidden(false)
        
        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        activeEventMonitors.append(
            NSEvent.addLocalMonitorForEvents(matching: eventMask.union(.leftMouseUp)) {event in
                return self.trackClick(event: event) ? event : nil
            })
        activeEventMonitors.append(
            NSEvent.addGlobalMonitorForEvents(matching: eventMask) {event in
                _ = self.trackClick(event: event)
            })
    }
    
    private func trackClick(event: NSEvent) -> Bool {
        if let eventWindow = event.window, eventWindow == window {
            // If the event is a mouse event within the popup, then it's either a mouseup to finish a click
            // (including a long click, and even including one that's actually a drag under the hood) or it's
            // an event to start the click. If we start the click, ignore the event. If it's the end of the
            // click, we'll handle the select.
            if event.type != .leftMouseUp {
                return false
            }
            
            if let contents = contents {
                let locationInContents = contents.asView.convert(event.locationInWindow, from: nil)
                // The click may have happened outside the popup; in that case, just return. Otherwise,
                // let the popup handle it.
                if contents.asView.bounds.contains(locationInContents) {
                    contents.handleClick(at: locationInContents)
                }
            }
            close()
            return false
        }

        var shouldClose = true // Most clicks close the popups; the only exception is clicking in the text field
        var continueProcessingEvent = true // See below for the one exception.
        let closeButton = parent.pulldownButton!
        if let eventWindow = event.window, eventWindow == closeButton.window {
            // If the click was on the button that opens this popup, we want to suppress the event. If we don't,
            // the button will just open the popup back up.
            if closeButton.contains(pointInWindowCoordinates: event.locationInWindow) {
                continueProcessingEvent = false
            } else if parent.contains(pointInWindowCoordinates: event.locationInWindow) {
                // Don't close if they click within the text field
                shouldClose = false
            }
        }
        if shouldClose {
            parent.window?.makeFirstResponder(nil)
            close()
        }
        return continueProcessingEvent
    }
    
    func contentSizeChanged() {
        scrollView.invalidateIntrinsicContentSize()
        scrollView.layoutSubtreeIfNeeded()
        if let docViewBounds = scrollView.documentView?.bounds {
            window.setContentSize(docViewBounds.size)
        }
        parent.adjustPopupLocation()
    }
    
    func setText(to string: String) {
        parent.stringValue = string
        parent.onTextChange()
    }
    
    func scroll(to bounds: NSRect, within: NSView) {
        let targetFrame = within.convert(bounds, to: scrollView.documentView)
        let scrollVisibleRect = scrollView.contentView.documentVisibleRect
        var scrollPoint: NSPoint?
        if targetFrame.maxY > scrollVisibleRect.maxY {
            // Scroll down. the scroll-to point is the top-left point, which should be the bottom-left point of the
            // option's rect *minus* the overall height.
            scrollPoint = NSPoint(
                x: targetFrame.minX,
                y: targetFrame.maxY - scrollVisibleRect.height)
        } else if targetFrame.minY < scrollVisibleRect.minY {
            // Scroll up; we just need to scroll to the top-left point
            scrollPoint = NSPoint(x: targetFrame.minX, y: targetFrame.minY)
        }
        if scrollPoint != nil {
            scrollView.contentView.scroll(to: scrollPoint!)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        activeEventMonitors.compactMap{$0}.forEach { NSEvent.removeMonitor($0) }
        activeEventMonitors.removeAll()
        scrollView.setAccessibilityHidden(true)
    }
}

enum Direction {
    case up
    case down
}

protocol TextFieldWithPopupCallbacks {
    /// Call this whenever you resize the popup's contents.
    func contentSizeChanged()
    /// Scroll up or down to the given rect, which is specified within the given NSView's coordinate system.
    func scroll(to bounds: NSRect, within: NSView)
    /// Set the enclosing field's text. This does not close the popup.
    func setText(to string: String)
}

protocol TextFieldWithPopupContents {
    var asView: NSView { get }
    func willShow(callbacks: TextFieldWithPopupCallbacks)
    func moveSelection(_ direction: Direction)
    
    /// Invoked when the text field's value changes. This method returns a string to autocomplete to, which may
    /// be the same as the given string.
    func onTextChanged(to newValue: String) -> String
    
    /// Handle a click at a given point, which will be in `asView`'s coordinates.
    ///
    /// This will close the pop that contain the contents this object represents. If the click represented the user
    /// selecting text, use `callbacks.setText(to:)` to convey that back to the popup.
    func handleClick(at point: NSPoint)
}
