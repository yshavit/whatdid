// whatdid?

import Cocoa

class TextOptionsList: WdView, TextFieldWithPopupContents {
    fileprivate static let PINNED_OPTIONS_COUNT = 3
    fileprivate static let labelAttrs: [NSAttributedString.Key : Any] = [
        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize * 0.9),
        .foregroundColor: NSColor.systemGray,
        .underlineColor: NSColor.systemGray,
        .underlineStyle: NSUnderlineStyle.single.rawValue
    ]
    fileprivate static let hrSeparatorAttrs: [NSAttributedString.Key : Any] = [
        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
        .strikethroughColor: NSColor.separatorColor
    ]
    
    private var textView: TrackingTextView!
    private var mouseoverHighlight: NSVisualEffectView!
    private var arrowSelectionHighlight: NSVisualEffectView!
    private var callbacks: TextFieldWithPopupCallbacks!
    
    private var selectionIdx: Int? {
        didSet {
            updateSelection()
        }
    }
    
    private var filterByText = "" {
        didSet {
            updateText()
        }
    }
    
    var options = [String]() {
        didSet {
            updateText()
        }
    }
    
    var asView: NSView {
        self
    }
    
    func willShow(callbacks: TextFieldWithPopupCallbacks) {
        self.callbacks = callbacks
    }
    
    func moveSelection(_ direction: Direction) {
        let largestIdx = optionInfosByMinY.entries.count - 1
        var idx: Int
        if let selectionIdx = selectionIdx {
            idx = selectionIdx + (direction == .up ? -1 : 1)
            if idx > largestIdx {
                idx = 0
            } else if idx < 0 {
                idx = largestIdx
            }
        } else if direction == .up {
            idx = largestIdx
        } else {
            idx = 0
        }
        selectionIdx = idx
    }
    
    func onTextChanged(to newValue: String) -> String {
        #warning("TODO")
        return newValue
    }
    
    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if let s = handleClick(at: loc) {
            callbacks.setText(to: s)
        }
    }
    
    private func updateSelection() {
        guard let selectionIdx = selectionIdx else {
            arrowSelectionHighlight.isHidden = true
            return
        }
        let selectedEntry = optionInfosByMinY.entries[selectionIdx].value
        let entryRect = NSRect(
            x: 0,
            y: selectedEntry.minY,
            width: frame.width,
            height: selectedEntry.maxY - selectedEntry.minY)
        arrowSelectionHighlight.frame = entryRect
        arrowSelectionHighlight.isHidden = false
        callbacks.scroll(to: entryRect, within: textView)
    }
    
    func handleClick(at point: NSPoint) -> String? {
        return option(at: point)?.stringValue
    }
    
    override func wdViewInit() {
        textView = TrackingTextView()
        textView.isSelectable = false
        textView.isEditable = false
        let grafStyle = NSMutableParagraphStyle()
        grafStyle.setParagraphStyle(NSParagraphStyle.default)
        grafStyle.headIndent = 10.0
        grafStyle.alignment = .justified
        textView.defaultParagraphStyle = grafStyle
        
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        textView.mouseMoved = trackMouseMovement(_:)
        textView.startTracking()
        
        mouseoverHighlight = NSVisualEffectView()
        arrowSelectionHighlight = NSVisualEffectView()
        arrowSelectionHighlight.isEmphasized = true
        arrowSelectionHighlight.state = .active
        arrowSelectionHighlight.material = .selection
        arrowSelectionHighlight.blendingMode = .behindWindow
        
        textView.wantsLayer = true
        textView.drawsBackground = false
        
        addSubview(mouseoverHighlight)
        addSubview(arrowSelectionHighlight)
        addSubview(textView)
        textView.anchorAllSides(to: self)
    }
    
    override func initializeInterfaceBuilder() {
        options = ["alpha", "bravo", "charlie"]
    }
    
    override var isFlipped : Bool {
        get {
            return true // This lets our coordinate system be the same as the textView container's.
        }
    }

    private var optionInfosByMinY = SortedMap<CGFloat, OptionInfo>()
    
    private func option(at point: NSPoint) -> OptionInfo? {
        // Find its optionInfo by looking up `y` in the optionInfosByMinY map. This will get us the
        // highest entry that starts at or below the point. We then need to check that the point
        // isn't *after* that entry, which could happen if there's a gap between entries (for example,
        // because of a separator line).
        if let option = optionInfosByMinY.find(highestEntryLessThanOrEqualTo: point.y), point.y < option.maxY {
            return option
        }
        return nil
    }
    
    private func trackMouseMovement(_ point: NSPoint?) {
        if let point = point,
           let highlighted = option(at: point)
        {
            mouseoverHighlight.frame = NSRect(
                x: 0,
                y: highlighted.minY,
                width: textView.bounds.width,
                height: highlighted.maxY - highlighted.minY)
            mouseoverHighlight.isHidden = false
        } else {
            mouseoverHighlight.isHidden = true
        }
    }
        
    private func updateText() {
        guard let storage = textView.textStorage, let p = textView.defaultParagraphStyle else {
            textView.string = "<error>"
            wdlog(.error, "Couldn't find storage or default paragraph style")
            return
        }
        
        optionInfosByMinY.removeAll()
        if options.isEmpty {
            storage.setAttributedString(NSAttributedString(
                string: "(no previous entries)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize * 0.9),
                    .foregroundColor: NSColor.systemGray,
                    .underlineColor: NSColor.systemGray,
                ]))
            return
        }
        let fullText = NSMutableAttributedString()
        var optionRanges = [NSRange]()
        var italicRanges = [NSRange]()
        let hrSeparatorText = "\r\u{00A0}\u{0009}\u{00A0}\n" // https://stackoverflow.com/a/65994719/1076640.
        
        func addLabel(_ labelText: String, with attributes: [NSAttributedString.Key : Any], italic: Bool) {
            if italic {
                italicRanges.append(NSRange(location: fullText.length, length: labelText.count))
            }
            fullText.append(NSAttributedString(string: labelText, attributes: attributes))
        }
        
        for (i, optionText) in options.enumerated() {
            if i == 0 {
                addLabel("recent", with: TextOptionsList.labelAttrs, italic: true)
            } else if i == TextOptionsList.PINNED_OPTIONS_COUNT {
                addLabel(hrSeparatorText, with: TextOptionsList.hrSeparatorAttrs, italic: false)
                addLabel("matched", with: TextOptionsList.labelAttrs, italic: true)
            }
            fullText.append(NSAttributedString(string: "\n"))
            let rangeStart = fullText.length
            fullText.append(NSAttributedString(string: optionText, attributes: [
                .font: NSFont.labelFont(ofSize: NSFont.systemFontSize),
                .paragraphStyle: p
            ]))
            optionRanges.append(NSRange(location: rangeStart, length: optionText.count))
        }
        storage.setAttributedString(fullText)

        for labelRange in italicRanges {
            storage.applyFontTraits(.italicFontMask, range: labelRange)
        }
        let fullTextNSString = NSString(string: fullText.string)
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            var optionInfoEntries = [(CGFloat, OptionInfo)]()
            for optionRange in optionRanges {
                let rect = layoutManager.boundingRect(forGlyphRange: optionRange, in: textContainer)
                let optionText = fullTextNSString.substring(with: optionRange)
                optionInfoEntries.append((
                    rect.minY,
                    OptionInfo(minY: rect.minY, maxY: rect.maxY, stringValue: optionText)));
            }
            optionInfosByMinY.add(kvPairs: optionInfoEntries)
        } else {
            wdlog(.warn, "textView no layoutManager or textContainer")
        }
    }
    
    private struct OptionInfo {
        let minY: CGFloat
        let maxY: CGFloat
        let stringValue: String
    }
}

fileprivate class TrackingTextView: NSTextView {
    
    /// Handle a mouse move event. The point is `nil` if the mouse exited this text area. Otherwise, the point is in the area's coordinate system.
    var mouseMoved: ((NSPoint?) -> Void) = {_ in }
    
    func startTracking() {
        addTrackingArea(NSTrackingArea(
            rect: NSRect.zero,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self))
    }
    
    override func mouseMoved(with event: NSEvent) {
        let boundsPos = self.convert(event.locationInWindow, from: nil)
        mouseMoved(boundsPos)
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseMoved(nil)
    }
}
