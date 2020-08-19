// whatdid?

import Cocoa

class AutoCompletingField: NSTextField {
    
    private static let PINNED_OPTIONS_COUNT = 3
    
    private var pulldownButton: NSButton!
    private var popupManager: PopupManager!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        useAutoLayout()
        
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
        
        pulldownButton = NSButton()
        pulldownButton.useAutoLayout()
        addSubview(pulldownButton)
        // button styling
        pulldownButton.imageScaling = .scaleProportionallyDown
        pulldownButton.bezelStyle = .smallSquare
        pulldownButton.state = .off
        pulldownButton.setButtonType(.momentaryPushIn)
        pulldownButton.imagePosition = .imageOnly
        pulldownButton.image = NSImage(named: NSImage.touchBarGoDownTemplateName)
        if let pulldownCell = pulldownButton.cell as? NSButtonCell {
            pulldownCell.isBordered = false
            pulldownCell.backgroundColor = .controlAccentColor
        }
        // button positioning
        pulldownButton.topAnchor.constraint(equalTo: topAnchor).isActive = true
        pulldownButton.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
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
        
        popupManager = PopupManager(closeButton: pulldownButton, onSelect: self.optionClicked(value:))
    }
    
    var options: [String] {
        get {
            return popupManager.options
        }
        set (values) {
            popupManager.options = values
        }
    }
    
    /// Set the cursor to the arrow (instead of NSTextField's default I-beam) when hovering over the button
    override func mouseMoved(with event: NSEvent) {
        if pulldownButton.frame.contains(convert(event.locationInWindow, from: nil)) {
            NSCursor.arrow.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        let succeeded = super.becomeFirstResponder()
        if succeeded {
            showOptions()
        }
        return succeeded
    }
    
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        if let event = NSApp.currentEvent {
            if event.type == .keyDown {
                if let specialKey = event.specialKey {
                    if specialKey == .delete {
                        // TODO handle delete. Need to worry about (1) deleting the selected range to clear it,
                        // (2) deleting at the end of the string (thus allowing more matches), (3) deleting at
                        // the middle (thus having no matches, maybe?)
                        print("delete")
                        // TODO unify with the matching code below
                        let topMatch = popupManager.match(currentEditor()!.string)
                        print("top match: \(topMatch ?? "<none>")")
                    } else {
                        print("unknown special key: \(specialKey)")
                    }
                } else {
//                    print("chars=\(event.characters): range=\(editor.selectedRange), string=\(editor.string)")
                    // TODO unify with the matching code above
                    let editor = currentEditor()!
                    let currentString = editor.string
                    if editor.selectedRange.location + editor.selectedRange.length == currentString.count {
//                        print("at end")
                    }
                    // TODO let's worry about auto-complete later, and for now just do the filtering
                    let topMatch = popupManager.match(currentString)
                    print("top match: \(topMatch ?? "<none>")")
                }
            }
        }
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
    
    private func showOptions() {
        popupManager.show(
            minWidth: frame.width,
            matching: stringValue,
            atTopLeft: window!.convertPoint(toScreen: frame.origin))
    }
    
    private class PopupManager: NSObject, NSWindowDelegate {
        private var activeEventMonitors = [Any?]()
        private let optionsPopup: NSPanel
        private let onSelect: (String) -> Void
        private let closeButton: NSView
        
        init(closeButton: NSView, onSelect: @escaping (String) -> Void) {
            self.closeButton = closeButton
            self.onSelect = onSelect
            optionsPopup = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 90),
                styleMask: [.fullSizeContentView],
                backing: .buffered,
                defer: false)
            optionsPopup.contentView = NSStackView()
            super.init()
            optionsPopup.delegate = self
            mainStack.useAutoLayout()
            mainStack.orientation = .vertical
        }
        
        var options: [String] {
            get {
                return menuItems.map { $0.labelString }
            }
            set (values) {
                mainStack.views.forEach { $0.removeFromSuperview() }
                for option in values {
                    let itemView = MenuItemView()
                    itemView.labelString = option
                    itemView.onSelect = onSelect
                    mainStack.addArrangedSubview(itemView)
                }
                
                if values.count > AutoCompletingField.PINNED_OPTIONS_COUNT {
                    // TODO add separator
                }
            }
        }
        
        private var menuItems: [MenuItemView] {
            return mainStack.arrangedSubviews.compactMap { $0 as? MenuItemView }
        }
        
        var windowIsVisible: Bool {
            return optionsPopup.isVisible
        }
        
        func close() {
            optionsPopup.close()
        }
        
        func match(_ lookFor: String) -> String? {
            let menuItems = self.menuItems
            var topResult: String?
            for i in 0..<menuItems.count {
                let menuItem = menuItems[i]
                let matched = SubsequenceMatcher.matches(lookFor: lookFor, inString: menuItem.labelString)
                if matched.isEmpty && (!lookFor.isEmpty) {
                    if i < AutoCompletingField.PINNED_OPTIONS_COUNT {
                        menuItem.setMatched(matched: [])
                    } else {
                        menuItem.isHidden = true
                    }
                } else {
                    if topResult == nil {
                        topResult = menuItem.labelString
                    }
                    menuItem.isHidden = false
                    menuItem.setMatched(matched: matched)
                }
            }
            optionsPopup.setContentSize(mainStack.fittingSize)
            return topResult
        }
        
        func show(minWidth: CGFloat, matching lookFor: String, atTopLeft: CGPoint) {
            guard !windowIsVisible else {
                return
            }
            mainStack.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth).isActive = true
            mainStack.layoutSubtreeIfNeeded()
            var popupOrigin = atTopLeft
            popupOrigin.y -= (optionsPopup.frame.height + 4)
            optionsPopup.setFrameOrigin(popupOrigin)
            _ = match(lookFor)
            optionsPopup.display()
            optionsPopup.setIsVisible(true)
            
            let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            activeEventMonitors.append(
                NSEvent.addLocalMonitorForEvents(matching: eventMask) {event in
                    return self.trackClick(event: event) ? event : nil
                })
            activeEventMonitors.append(
                NSEvent.addGlobalMonitorForEvents(matching: eventMask) {event in
                    _ = self.trackClick(event: event)
                })
        }
        
        func windowWillClose(_ notification: Notification) {
            activeEventMonitors.compactMap{$0}.forEach { NSEvent.removeMonitor($0) }
            activeEventMonitors.removeAll()
        }
        
        /// Convenience getter
        private var mainStack: NSStackView {
            return optionsPopup.contentView! as! NSStackView
        }
        
        private func trackClick(event: NSEvent) -> Bool {
            close()
            // If the click was on the button that opens this popup, we want to suppress the event. Otherwise,
            // the button will just open the popup back up.
            if let eventWindow = event.window, eventWindow == closeButton.window {
                let eventLocationInButtonSuperview = closeButton.superview!.convert(event.locationInWindow, from: nil)
                if closeButton.frame.contains(eventLocationInButtonSuperview) {
                    return false
                }
            }
            return true
        }
    }
    
    private func optionClicked(value: String) {
        print("clicked: \(value)")
    }
    
    private class MenuItemView: NSView {
        private var decoratedLabelView: NSTextField?
        private var effectView: NSVisualEffectView!
        private var textView: NSTextField!
        fileprivate var onSelect: (String) -> Void = {_ in return}
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }
        
        override init(frame: NSRect) {
            super.init(frame: frame)
            commonInit()
        }
        
        func setMatched(matched: [NSRange]) {
            let attributedLabel = NSMutableAttributedString(string: labelString)
            matched.forEach {range in
                attributedLabel.addAttributes(
                    [
                        .foregroundColor: NSColor.findHighlightColor,
                        .backgroundColor: NSColor.windowBackgroundColor,
                        .underlineColor: NSColor.findHighlightColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                    ],
                    range: range)
            }
            textView.attributedStringValue = attributedLabel
        }
        
        var decorationLabel: String? {
            get {
                return decoratedLabelView?.stringValue
            }
            set(maybeValue) {
                if let value = maybeValue {
                    if decoratedLabelView == nil {
                        let decoratedLabelView = NSTextField(labelWithString: "")
                        self.decoratedLabelView = decoratedLabelView
                        decoratedLabelView.useAutoLayout()
                        
                        addSubview(decoratedLabelView)
                        decoratedLabelView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                        decoratedLabelView.textColor = NSColor.controlLightHighlightColor
                        decoratedLabelView.topAnchor.constraint(equalTo: topAnchor).isActive = true
                        decoratedLabelView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4).isActive = true
                    }
                    let attributedValue = NSMutableAttributedString(string: value)
                    attributedValue.applyFontTraits(.italicFontMask, range: attributedValue.string.fullNsRange())
                    decoratedLabelView!.attributedStringValue = attributedValue
                } else if decoratedLabelView != nil {
                    decoratedLabelView!.removeFromSuperview()
                    decoratedLabelView = nil
                }
            }
        }
        
        var asMenuItem: NSMenuItem {
            get {
                let item = NSMenuItem()
                item.target = self
                item.action = #selector(ignoreThis(_:))
                item.view = self
                return item
            }
        }
        
        private func commonInit() {
            useAutoLayout()
            
            // Highlight when hover
            effectView = NSVisualEffectView()
            effectView.useAutoLayout()
            effectView.state = .active
            effectView.material = .selection
            effectView.isEmphasized = true
            effectView.blendingMode = .behindWindow
            addSubview(effectView)
            effectView.anchorAllSides(to: self)
            
            // The actual label (its value is set by labelString)
            textView = NSTextField(labelWithString: "")
            textView.useAutoLayout()
            addSubview(textView)
            textView.anchorAllSides(to: self)
        }
        
        var labelString: String { // TODO rename to "value"?
            get {
                return textView.stringValue
            }
            set (value) {
                textView.stringValue = value
            }
        }
        
        override func mouseUp(with event: NSEvent) {
            onSelect(labelString)
        }
        
        override func draw(_ dirtyRect: NSRect) {
            let isHighlighted = enclosingMenuItem?.isHighlighted ?? false
            effectView.isHidden = !isHighlighted
            super.draw(dirtyRect)
        }
        
        @objc private func ignoreThis(_ option: NSMenuItem) {
            // Don't do anything. We need an action on the NSMenuItem in order for the isHighlighted to update;
            // but I can't get the click to ever actually *do* anything, so instead I have the onAction handler
            // to mimic the same. This is probably a wrong approach, but whatever, it works.
        }
    }
    
    private class ShrunkenTextFieldCell: NSTextFieldCell {
        
        fileprivate var widthAdjustment: () -> CGFloat = { 0 }
        
        override func drawingRect(forBounds rect: NSRect) -> NSRect {
            let fromSuper = super.drawingRect(forBounds: rect)
            return NSRect(x: fromSuper.minX, y: fromSuper.minY, width: fromSuper.width - widthAdjustment(), height: fromSuper.height)
        }
    }
}
