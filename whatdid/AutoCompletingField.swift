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
        
        popupManager = PopupManager(closeButton: pulldownButton, onSelect: { self.stringValue = $0 })
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
        private var matchedSectionSeparators = [NSView]()
        
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
            mainStack.edgeInsets.bottom = 4
            mainStack.orientation = .vertical
            mainStack.alignment = .leading
            mainStack.spacing = 0
        }
        
        var options: [String] {
            get {
                return optionFields.map { $0.stringValue }
            }
            set (values) {
                mainStack.views.forEach { $0.removeFromSuperview() }
                mainStack.subviews.forEach { $0.removeFromSuperview() }
                matchedSectionSeparators.removeAll()
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
        
        func close() {
            optionsPopup.close()
        }
        
        func match(_ lookFor: String) -> String? {
            let optionFields = self.optionFields
            var topResult: String?
            var greatestMatchedIndex = -1
            for i in 0..<optionFields.count {
                let item = optionFields[i]
                let matched = SubsequenceMatcher.matches(lookFor: lookFor, inString: item.stringValue)
                if matched.isEmpty && (!lookFor.isEmpty) {
                    if i < AutoCompletingField.PINNED_OPTIONS_COUNT {
                        item.setMatches([])
                    } else {
                        item.isHidden = true
                    }
                } else {
                    if topResult == nil {
                        topResult = item.stringValue
                    }
                    greatestMatchedIndex = max(greatestMatchedIndex, i)
                    item.isHidden = false
                    item.setMatches(matched)
                }
            }
            let showMatchedSectionSeparators = greatestMatchedIndex >= AutoCompletingField.PINNED_OPTIONS_COUNT
            matchedSectionSeparators.forEach { $0.isHidden = !showMatchedSectionSeparators }
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
                NSEvent.addLocalMonitorForEvents(matching: eventMask.union(.leftMouseUp)) {event in
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
        
        private func addGroupingLabel(text: String, under topAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor>) -> NSView {
            let label = NSTextField(labelWithString: "")
            label.useAutoLayout()
            mainStack.addSubview(label)
            label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = NSColor.controlLightHighlightColor
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
                // We can't just let the Option handle this. If the user holds down on one element and then
                // "drags" to another, the mouseup belongs to the first element; we really want it to belong
                // to where the cursor ended up. So, we'll get the location and find the view there, and then
                // walk up the superview chain until we get to an Option (whose stringValue we then get) or
                // see that there's nothing there
                let locationInSuperview = mainStack.superview!.convert(event.locationInWindow, from: nil)
                if let hitItem = mainStack.hitTest(locationInSuperview) {
                    var viewSearch: NSView? = hitItem
                    while viewSearch != nil {
                        if let option = viewSearch as? Option {
                            onSelect(option.stringValue)
                            break
                        }
                        viewSearch = viewSearch?.superview
                    }
                }
                close()
                return false
                
            }
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
        
        class Option: NSView {
            static let paddingH: CGFloat = 2.0
            static let paddingV: CGFloat = 2.0
            private var label: NSTextField!
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
                highlightOverlay.isEmphasized = true
                highlightOverlay.blendingMode = .behindWindow
                highlightOverlay.isHidden = true
                addSubview(highlightOverlay)
                highlightOverlay.anchorAllSides(to: self)
                
                let labelPadding = NSView()
                addSubview(labelPadding)
                labelPadding.anchorAllSides(to: self)
                
                label = NSTextField(labelWithString: "")
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
                            .foregroundColor: NSColor.findHighlightColor,
                            .underlineColor: NSColor.findHighlightColor,
                            .underlineStyle: NSUnderlineStyle.single.rawValue,
                        ],
                        range: range)
                }
                label.attributedStringValue = attributedLabel
            }
            
            override func mouseEntered(with event: NSEvent) {
                highlightOverlay.isHidden = false
            }
            
            override func mouseExited(with event: NSEvent) {
                highlightOverlay.isHidden = true
            }
        }
    }
    
    /// An NSTextFieldCell with a smaller frame, to accommodate the popup button.
    private class ShrunkenTextFieldCell: NSTextFieldCell {
        
        fileprivate var widthAdjustment: () -> CGFloat = { 0 }
        
        override func drawingRect(forBounds rect: NSRect) -> NSRect {
            let fromSuper = super.drawingRect(forBounds: rect)
            return NSRect(x: fromSuper.minX, y: fromSuper.minY, width: fromSuper.width - widthAdjustment(), height: fromSuper.height)
        }
    }
}
