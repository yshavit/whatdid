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
            return menu?.items.compactMap { ($0.view as? MenuItemView)?.labelString } ?? []
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
                attachLabelToOption("recent", to: menuItem)
            case AutoCompletingField.PINNED_OPTIONS_COUNT:
                menu.addItem(NSMenuItem.separator())
            case AutoCompletingField.PINNED_OPTIONS_COUNT + 2:
                // This is the first non-pinned option; remember that PINNED_OPTIONS_COUNT + 1 is the separator.
                attachLabelToOption("matched", to: menuItem)
            default:
                break
            }
        }
    }
    
    private func attachLabelToOption(_ label: String, to item: NSMenuItem) {
        if let itemView = item.view {
            let attributedLabel = NSMutableAttributedString(string: label)
            attributedLabel.applyFontTraits(.italicFontMask, range: attributedLabel.string.fullNsRange())
            let recentsLabel = NSTextField(labelWithAttributedString: attributedLabel)
            recentsLabel.useAutoLayout()
            
            itemView.addSubview(recentsLabel)
            recentsLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            recentsLabel.textColor = NSColor.controlLightHighlightColor
            recentsLabel.topAnchor.constraint(equalTo: itemView.topAnchor).isActive = true
            recentsLabel.trailingAnchor.constraint(equalTo: itemView.trailingAnchor, constant: -4).isActive = true
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
        
        var labelString: String {
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
