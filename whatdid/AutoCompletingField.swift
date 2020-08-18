// whatdid?

import Cocoa

class AutoCompletingField: NSTextField {
    
    private static let PINNED_OPTIONS_COUNT = 5
    
    private var pulldownButton: NSButton!
    
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
        
        options = []
    }
    
    override func mouseMoved(with event: NSEvent) {
        if pulldownButton.frame.contains(convert(event.locationInWindow, from: nil)) {
            NSCursor.arrow.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }
    
    var options: [String] {
        get {
            return menuItems.map { $0.labelString }
        }
        set(values) {
            let menu: NSMenu
            if let existingMenu = self.menu {
                menu = existingMenu
                menu.removeAllItems()
            } else {
                menu = NSMenu()
                self.menu = menu
            }
            buildItems(options: values, on: menu)
        }
    }
    
    private func buildItems(options: [String], on menu: NSMenu) {
        for option in options {
            let itemView = MenuItemView()
            itemView.labelString = option
            itemView.onSelect = self.optionClicked
            let menuItem = itemView.asMenuItem
            menu.addItem(menuItem)
            
            switch menu.numberOfItems {
            case 1:
                // First item; put in the "recents" label
                itemView.decorationLabel = "recent"
            case AutoCompletingField.PINNED_OPTIONS_COUNT:
                menu.addItem(NSMenuItem.separator())
            case AutoCompletingField.PINNED_OPTIONS_COUNT + 2:
                // This is the first non-pinned option; remember that PINNED_OPTIONS_COUNT + 1 is the separator.
                itemView.decorationLabel = "matched"
            default:
                break
            }
        }
    }
    
    private var menuItems: [MenuItemView] {
        return menu?.items.compactMap {$0.view as? MenuItemView} ?? []
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
                    } else {
                        print("unknown special key: \(specialKey)")
                    }
                } else {
//                    print("chars=\(event.characters): range=\(editor.selectedRange), string=\(editor.string)")
                    let editor = currentEditor()!
                    let currentString = editor.string
                    if editor.selectedRange.location + editor.selectedRange.length == currentString.count {
//                        print("at end")
                    }
                    // TODO let's worry about auto-complete later, and for now just do the filtering
                    let menuItems = self.menuItems
                    for i in 0..<menuItems.count {
                        let menuItem = menuItems[i]
                        let matched = SubsequenceMatcher.matches(lookFor: currentString, inString: menuItem.labelString)
                        if matched.isEmpty {
                            if i < AutoCompletingField.PINNED_OPTIONS_COUNT {
                                menuItem.setMatched(matched: [])
                            } else {
                                menuItem.isHidden = true
                            }
                        } else {
                            menuItem.setMatched(matched: matched)
                        }
                    }
                }
            }
        }
    }
    
    
    
    @objc private func buttonClicked() {
        menu!.minimumWidth = frame.width
        menu!.popUp(positioning: nil, at: NSPoint(x: 0, y: frame.height + 4), in: self)
    }
    
    private func optionClicked(value: String) {
        menu?.cancelTrackingWithoutAnimation()
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
                        .backgroundColor: NSColor.selectedControlColor,
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
