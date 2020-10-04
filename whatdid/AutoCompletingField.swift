// whatdid?

import Cocoa

class AutoCompletingField: NSView, NSAccessibilityGroup {
    
    fileprivate static let PINNED_OPTIONS_COUNT = 3
    
    fileprivate var textFieldView: AutoCompletingFieldView!
    fileprivate var popupManager: PopupManager!
    var action: (AutoCompletingField) -> Void = {_ in}
    var optionsLookupOnFocus: (() -> [String])?
    var onTextChange: (() -> Void) = {}
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        popupManager = PopupManager(parent: self)
        popupManager.window.setAccessibilityParent(self)
        
        textFieldView = AutoCompletingFieldView()
        addSubview(textFieldView)
        setAccessibilityChildren(nil) // we'll be adding textFieldView in our overload of accessibilityChildren()
        textFieldView.anchorAllSides(to: self)
        textFieldView.parent = self
        textFieldView.target = self
        textFieldView.action = #selector(textFieldViewAction(_:))

        setAccessibilityEnabled(true)
        setAccessibilityRole(.comboBox)
    }
    
    @objc private func textFieldViewAction(_ sender: NSTextField) {
        action(self)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return window?.makeFirstResponder(textField) ?? false
    }
    
    override func accessibilityChildren() -> [Any]? {
        var result = [Any]()
        result.append(contentsOf: textFieldView.accessibilityChildren()!)
        result.append(contentsOf: textFieldView.pulldownButton.accessibilityChildren()!)
        if popupManager.windowIsVisible {
            result.append(popupManager.scrollView!)
        }
        if let superChildren = super.accessibilityChildren() {
            result.append(contentsOf: superChildren)
        }
        return result
    }

    var options: [String] {
        get {
            return popupManager.options
        }
        set (values) {
            popupManager.options = values
        }
    }
    
    var textField: NSTextField {
        return textFieldView
    }
}

fileprivate class AutoCompletingFieldView: WhatdidTextField, NSTextViewDelegate, NSTextFieldDelegate {
    
    var previousAutocompleteHeadLength = 0
    var shouldAutocompleteOnTextChange = false
    
    var parent: AutoCompletingField!
    var pulldownButton: NSButton!
    
    private var popupManager: PopupManager {
        return parent.popupManager
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override var nextKeyView: NSView? {
        get {
            parent.nextKeyView
        }
        set(value) {
            NSLog("Unexpected mutation of AutoCompletingFieldView.nextKeyView")
        }
    }
    
    override var nextResponder: NSResponder? {
        get {
            parent.nextResponder
        }
        set(value) {
            NSLog("Unexpected mutation of AutoCompletingFieldView.nextResponder")
        }
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        if parent.popupManager.windowIsVisible, let window = window {
            let popup = parent.popupManager.window
            guard window.screen == popup.screen else {
                NSLog("window screen and autocomplete popup screen were different")
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
    
    override var nextValidKeyView: NSView? {
        parent.nextValidKeyView
    }
    
    override var previousKeyView: NSView? {
        parent.previousKeyView
    }
    
    override var previousValidKeyView: NSView? {
        parent.previousValidKeyView
    }
    
    private func commonInit() {
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
        popupManager.accessibilityIdentifierChanged()
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
            popupManager.moveSelection(down: true)
            return true
        case #selector(moveUp(_:)):
            popupManager.moveSelection(down: false)
            return true
        case #selector(cancelOperation(_:)):
            if popupManager.windowIsVisible {
                popupManager.close()
                return true
            }
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
        if let optionsLookup = parent.optionsLookupOnFocus {
            parent.options = optionsLookup()
        }
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
        let maybeAutocomplete = popupManager.match(stringValue)
        // If the selection is at the tail of the string, fill in the autocomplete.
        if shouldAutocompleteOnTextChange, let autoComplete = maybeAutocomplete {
            let charsToAutocomplete = autoComplete.count - stringValue.count
            if charsToAutocomplete > 0 {
                let autocompleTail = String(autoComplete.dropFirst(stringValue.count))
                let stringCountBeforeAutocomplete = stringValue.count
                stringValue += autocompleTail
                currentEditor()!.selectedRange = NSRange(location: stringCountBeforeAutocomplete, length: charsToAutocomplete)
            }
        }
        parent.onTextChange()
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        popupManager.close()
    }
    
    @objc private func buttonClicked() {
        if popupManager.windowIsVisible {
            // Note: we shouldn't ever actually get here, but I'm putting it just in case.
            // If the popup is open, any click outside of it (including to this button) will close it.
            NSLog("Unexpectedly saw button press while options popup was open on \(idForLogging)")
            popupManager.close()
        } else {
            if !(window?.makeFirstResponder(self) ?? false) {
                NSLog("Couldn't make first responder: \(idForLogging)")
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
            matching: stringValue,
            atTopLeft: originWithinScreen)
    }
    
    private class NoKeyButton: NSButton {
        override var canBecomeKeyView: Bool {
            return false
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
}

fileprivate class PopupManager: NSObject, NSWindowDelegate {
    static let HEIGHT_FROM_BOTTOM_OF_FIELD: CGFloat = 2
    private var activeEventMonitors = [Any?]()
    private let optionsPopup: NSPanel
    private let parent: AutoCompletingField
    private var matchedSectionSeparators = [NSView]()
    private let mainStack: NSStackView
    private var setWidth: ((CGFloat) -> Void)!
    var scrollView: NSScrollView!
    
    init(parent: AutoCompletingField) {
        self.parent = parent
        optionsPopup = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 90),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false)
        optionsPopup.hasShadow = true
        mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.detachesHiddenViews = true
        
        super.init()
        optionsPopup.delegate = self
        mainStack.useAutoLayout()
        mainStack.edgeInsets.bottom = 4
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 0
        
        // Put the main stack inside a scroll
        let scroll = NSScrollView()
        scrollView = scroll
        scroll.setAccessibilityHidden(true)
        scroll.useAutoLayout()
        scroll.contentView.anchorAllSides(to: scroll)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true

        let flipped = FlippedView()
        flipped.useAutoLayout()
        flipped.addSubview(mainStack)
        mainStack.anchorAllSides(to: flipped)
        scroll.documentView = flipped

        // Try to have the scroll's content view be as big as the mainstack; but cap it at 150.
        // Also create a constraint for the width, which we'll set as we open the popup.
        scroll.contentView.heightAnchor.constraint(lessThanOrEqualTo: mainStack.heightAnchor).isActive = true
        scroll.heightAnchor.constraint(lessThanOrEqualToConstant: 150).isActive = true
        let widthConstraint = scroll.contentView.widthAnchor.constraint(equalToConstant: 100) // any ol' value will do
        widthConstraint.isActive = true
        setWidth = { widthConstraint.constant = $0 } // ha, a mutable constant!

        scroll.contentView.widthAnchor.constraint(lessThanOrEqualTo: mainStack.widthAnchor).isActive = true
        optionsPopup.contentView = scroll
        optionsPopup.level = .popUpMenu
        optionsPopup.setAccessibilityChildren(nil)
        optionsPopup.setAccessibilityRole(.none)
        
        scroll.setAccessibilityParent(parent)
        scroll.setAccessibilityWindow(parent.window)
        scroll.setAccessibilityTopLevelUIElement(parent)
    }
    
    func accessibilityIdentifierChanged() {
        let baseId = parent.accessibilityIdentifier()
        if baseId.isEmpty {
            scrollView.setAccessibilityIdentifier(nil)
            optionFields.forEach { $0.setAccessibilityIdentifier(nil) }
        } else {
            scrollView.setAccessibilityIdentifier("\(baseId)__scrollarea")
            optionFields.enumerated().forEach { $1.setAccessibilityIdentifier("\(baseId)__option\($0)")}
        }
    }
    
    var options: [String] {
        get {
            return optionFields.map { $0.stringValue }
        }
        set (values) {
            
            mainStack.views.forEach { $0.removeFromSuperview() }
            mainStack.subviews.forEach { $0.removeFromSuperview() }
            matchedSectionSeparators.removeAll()
            if values.isEmpty {
                let labelString = NSAttributedString(string: "(no previous entries)", attributes: [
                    NSAttributedString.Key.foregroundColor: NSColor.systemGray,
                ])
                let noneLabel = NSTextField(labelWithAttributedString: labelString)
                noneLabel.useAutoLayout()
                noneLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                mainStack.addArrangedSubview(noneLabel)
                noneLabel.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
                return
            }
            for (i, optionText) in values.enumerated() {
                if i == AutoCompletingField.PINNED_OPTIONS_COUNT {
                    let separator = NSBox()
                    mainStack.addArrangedSubview(separator)
                    separator.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
                    separator.boxType = .separator
                    matchedSectionSeparators.append(separator)
                    matchedSectionSeparators.append(addGroupingLabel(text: "matched", under: separator.topAnchor))
                }
                let option = Option()
                option.stringValue = optionText
                mainStack.addArrangedSubview(option)
                option.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
            }
            if !values.isEmpty {
                _ = addGroupingLabel(text: "recent", under: mainStack.topAnchor)
            }
        }
    }
    
    private var optionFields: [Option] {
        return mainStack.arrangedSubviews.compactMap { $0 as? Option }
    }
    
    var windowIsVisible: Bool {
        return optionsPopup.isVisible
    }

    var window: NSWindow {
        return optionsPopup
    }
    
    func close() {
        optionsPopup.close()
    }
    
    func moveSelection(down moveDown: Bool) {
        if !windowIsVisible {
            parent.textFieldView.showOptions()
        }
        let visibleFields = self.optionFields.filter { !$0.isHidden }
        guard !visibleFields.isEmpty else {
            return
        }
        func lastOption(matchedIfPossible: Bool) -> Option {
            let idx = matchedIfPossible
                ? visibleFields.lastIndex(where: {!SubsequenceMatcher.matches(lookFor: parent.textField.stringValue, inString: $0.stringValue).isEmpty})
                : nil
            return visibleFields[idx ?? visibleFields.count - 1]
        }
        func firstOption(matchedIfPossible: Bool) -> Option {
            let idx = matchedIfPossible
                ? visibleFields.firstIndex(where: {!SubsequenceMatcher.matches(lookFor: parent.textField.stringValue, inString: $0.stringValue).isEmpty})
                : nil
            return visibleFields[idx ?? 0]
        }
        
        let selected: Option
        if let alreadySelectedIdx = visibleFields.firstIndex(where: {$0.isSelected}) {
            visibleFields[alreadySelectedIdx].isSelected = false
            if moveDown {
                selected = (alreadySelectedIdx + 1 >= visibleFields.count)
                    ? firstOption(matchedIfPossible: false)
                    : visibleFields[alreadySelectedIdx + 1]
            } else {
                selected = (alreadySelectedIdx == 0)
                    ? lastOption(matchedIfPossible: false)
                    : visibleFields[alreadySelectedIdx - 1]
            }
        } else if moveDown {
            selected = firstOption(matchedIfPossible: true)
        } else {
            selected = lastOption(matchedIfPossible: true)
        }
        selected.isSelected = true
        parent.textField.stringValue = selected.stringValue
        if let editor = parent.textField.currentEditor() {
            editor.selectedRange = NSRange(location: 0, length: selected.stringValue.count)
        }
        let optionFrameWithinDoc = selected.superview!.convert(selected.frame, to: scrollView.documentView)
        let scrollVisibleRect = scrollView.contentView.documentVisibleRect
        var scrollPoint: NSPoint?
        if optionFrameWithinDoc.maxY > scrollVisibleRect.maxY {
            // Scroll down. the scroll-to point is the top-left point, which should be the bottom-left point of the
            // option's rect *minus* the overall height.
            scrollPoint = NSPoint(
                x: optionFrameWithinDoc.minX,
                y: optionFrameWithinDoc.maxY - scrollVisibleRect.height)
        } else if optionFrameWithinDoc.minY < scrollVisibleRect.minY {
            // Scroll up; we just need to scroll to the top-left point
            scrollPoint = NSPoint(x: optionFrameWithinDoc.minX, y: optionFrameWithinDoc.minY)
        }
        if scrollPoint != nil {
            scrollView.contentView.scroll(to: scrollPoint!)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    func match(_ lookFor: String) -> String? {
        let originalFrame = optionsPopup.frame
        let optionFields = self.optionFields
        var shortestPrefixMatch: String?
        var greatestMatchedIndex = -1
        for i in 0..<optionFields.count {
            let item = optionFields[i]
            let matched = SubsequenceMatcher.matches(lookFor: lookFor, inString: item.stringValue)
            if matched.isEmpty && (!lookFor.isEmpty) {
                if i < AutoCompletingField.PINNED_OPTIONS_COUNT {
                    item.setMatches([])
                } else {
                    item.isHidden = true
                    item.isSelected = false
                }
            } else {
                let itemValue = item.stringValue
                if itemValue.starts(with: lookFor) {
                    let useItemValueAsShortestPrefixMatch: Bool
                    if let existing = shortestPrefixMatch {
                        useItemValueAsShortestPrefixMatch = itemValue.count < existing.count
                    } else {
                        useItemValueAsShortestPrefixMatch = true
                    }
                    if useItemValueAsShortestPrefixMatch {
                        shortestPrefixMatch = itemValue
                    }
                }
                greatestMatchedIndex = max(greatestMatchedIndex, i)
                item.isHidden = false
                item.setMatches(matched)
            }
        }
        let showMatchedSectionSeparators = greatestMatchedIndex >= AutoCompletingField.PINNED_OPTIONS_COUNT
        matchedSectionSeparators.forEach { $0.isHidden = !showMatchedSectionSeparators }
        optionsPopup.setContentSize(mainStack.fittingSize)
        let newFrame = optionsPopup.frame
        optionsPopup.setFrameOrigin(originalFrame.offsetBy(dx: 0, dy: originalFrame.height - newFrame.height).origin)
        return shortestPrefixMatch
    }
    
    func show(minWidth: CGFloat, matching lookFor: String, atTopLeft: CGPoint) {
        guard !windowIsVisible else {
            return
        }
        setWidth(minWidth)
        var popupOrigin = atTopLeft
        popupOrigin.y -= (optionsPopup.frame.height + PopupManager.HEIGHT_FROM_BOTTOM_OF_FIELD)
        optionsPopup.setFrameOrigin(popupOrigin)
        _ = match(lookFor)
        optionsPopup.display()
        optionsPopup.setIsVisible(true)
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
    
    func windowWillClose(_ notification: Notification) {
        optionFields.forEach { $0.isSelected = false }
        activeEventMonitors.compactMap{$0}.forEach { NSEvent.removeMonitor($0) }
        activeEventMonitors.removeAll()
        scrollView.setAccessibilityHidden(true)
    }
    
    private func addGroupingLabel(text: String, under topAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor>) -> NSView {
        let label = NSTextField(labelWithString: "")
        label.useAutoLayout()
        mainStack.addSubview(label)
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = NSColor.systemGray
        label.topAnchor.constraint(equalTo: topAnchor).isActive = true
        label.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -4).isActive = true
        
        let attributedValue = NSMutableAttributedString(string: text)
        attributedValue.applyFontTraits(.italicFontMask, range: attributedValue.string.fullNsRange())
        label.attributedStringValue = attributedValue
        return label
    }
    
    private func trackClick(event: NSEvent) -> Bool {
        if let eventWindow = event.window, eventWindow == optionsPopup {
            // If the event is a mouse event within the popup, then it's either a mouseup to finish a click
            // (including a long click, and even including one that's actually a drag under the hood) or it's
            // an event to start the click. If we start the click, ignore the event. If it's the end of the
            // click, we'll handle the select.
            if event.type != .leftMouseUp {
                return false
            }
            
            // Look for clicks within the Options popup.
            // We can't just let the Option handle clicks. If the user holds down on one element and then
            // "drags" to another, the mouseup belongs to the first element; we really want it to belong
            // to where the cursor ended up. So, we'll get the location and find the view there, and then
            // walk up the superview chain until we get to an Option (whose stringValue we then get) or
            // see that there's nothing there
            let locationInSuperview = mainStack.superview!.convert(event.locationInWindow, from: nil)
            if let hitItem = mainStack.hitTest(locationInSuperview) {
                var viewSearch: NSView? = hitItem
                // The hit happened in the cell; walk up the parent chain to the Option so we can find its value
                while viewSearch != nil {
                    if let option = viewSearch as? Option {
                        parent.textField.stringValue = option.stringValue
                        if let editor = parent.textField.currentEditor() {
                            editor.insertNewline(nil) // send the action
                        } else {
                            NSLog("Couldn't find editor")
                        }
                        break
                    }
                    viewSearch = viewSearch?.superview
                }
            }
            close()
            return false
        }

        var shouldClose = true // Most clicks close the popups; the only exception is clicking in the text field
        var continueProcessingEvent = true // See below for the one exception.
        let closeButton = parent.textFieldView.pulldownButton!
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
    
    class Option: NSView {
        static let paddingH: CGFloat = 4.0
        static let paddingV: CGFloat = 2.0
        private var _isSelected = false
        private var isMouseOver = false
        var label: NSTextField!
        private var highlightOverlay: NSVisualEffectView!
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            commonInit()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }
        
        private func commonInit() {
            highlightOverlay = NSVisualEffectView()
            highlightOverlay.useAutoLayout()
            highlightOverlay.state = .active
            highlightOverlay.material = .selection
            highlightOverlay.blendingMode = .behindWindow
            highlightOverlay.isHidden = true
            addSubview(highlightOverlay)
            highlightOverlay.anchorAllSides(to: self)
            
            let labelPadding = NSView()
            addSubview(labelPadding)
            labelPadding.anchorAllSides(to: self)
            
            label = NSTextField(labelWithString: "")
            label.cell!.setAccessibilityRole(.textField)
            label.useAutoLayout()
            labelPadding.addSubview(label)
            labelPadding.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: -Option.paddingH).isActive = true
            labelPadding.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: Option.paddingH).isActive = true
            labelPadding.topAnchor.constraint(equalTo: label.topAnchor, constant: -Option.paddingV).isActive = true
            labelPadding.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: Option.paddingV).isActive = true
            
            let pulldownButtonTracker = NSTrackingArea(
                rect: frame,
                options: [.inVisibleRect, .mouseEnteredAndExited, .activeAlways, .enabledDuringMouseDrag],
                owner: self)
            addTrackingArea(pulldownButtonTracker)
        }
        
        var stringValue: String {
            get {
                return label.stringValue
            }
            set(value) {
                label.stringValue = value
            }
        }
        
        func setMatches(_ matched: [NSRange]) {
            let attributedLabel = NSMutableAttributedString(string: stringValue)
            matched.forEach {range in
                attributedLabel.addAttributes(
                    [
                        .foregroundColor: NSColor.selectedTextColor,
                        .backgroundColor: NSColor.selectedTextBackgroundColor,
                        .underlineColor: NSColor.findHighlightColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                    ],
                    range: range)
            }
            label.attributedStringValue = attributedLabel
        }
        
        var isSelected: Bool {
            get {
                return _isSelected
            } set(value) {
                _isSelected = value
                label.cell!.setAccessibilitySelected(value)
                updateHighlight()
            }
        }
        
        override func mouseEntered(with event: NSEvent) {
            isMouseOver = true
            updateHighlight()
        }
        
        override func mouseExited(with event: NSEvent) {
            isMouseOver = false
            updateHighlight()
        }
        
        private func updateHighlight() {
            if isMouseOver || _isSelected {
                highlightOverlay.isEmphasized = _isSelected
                highlightOverlay.isHidden = false
            } else {
                highlightOverlay.isHidden = true
            }
        }
    }
}
