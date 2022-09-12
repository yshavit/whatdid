// whatdid?

import Cocoa

class TextOptionsList: WdView, TextFieldWithPopupContents {
    fileprivate static let PINNED_OPTIONS_COUNT = 3
    
    private var textView: TrackingTextView!
    private var mouseoverHighlight: NSVisualEffectView!
    private var arrowSelectionHighlight: NSVisualEffectView!
    private var callbacks: TextFieldWithPopupCallbacks!
    
    private var selectionIdx: Int? {
        didSet {
            updateSelection()
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
    
    class Glue: FlippedView {
        override var allowsVibrancy: Bool {
            true
        }
        
        private var requestedFrame: NSRect?
        fileprivate var heightConstraint: NSLayoutConstraint?
        
        override var frame: NSRect {
            get {
                requestedFrame ?? super.frame
            } set (value) {
                #warning("TODO I don't actually need this, ALL I need is the height constraint!")
                requestedFrame = value
                heightConstraint?.constant = value.height
                super.frame = value
                setBoundsSize(value.size)
            }
        }
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
    
    var options: [String] {
        get {
            return optionInfosByMinY.entries.map { $0.value.stringValue }
        }
        set (values) {
            guard let storage = textView.textStorage, let p = textView.defaultParagraphStyle else {
                textView.string = "<error>"
                wdlog(.error, "Couldn't find storage or default paragraph style")
                return
            }
            
            optionInfosByMinY.removeAll()
            if values.isEmpty {
                storage.setAttributedString(NSAttributedString(
                    string: "(no previous entries)",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize * 0.9),
                        .foregroundColor: NSColor.systemGray,
                        .underlineColor: NSColor.systemGray,
                    ]))
                return
            }
            var fullText = ""
            var optionRanges = [NSRange]()
            var labelRanges = [NSRange]()
            var hrRanges = [NSRange]()
            let hrSeparatorText = "\r\u{00A0}\u{0009}\u{00A0}\n" // https://stackoverflow.com/a/65994719/1076640.
            
            func addLabel(_ labelText: String, using range: inout [NSRange]) {
                range.append(NSRange(location: fullText.count, length: labelText.count))
                fullText += labelText
            }
            
            for (i, optionText) in values.enumerated() {
                if i == 0 {
                    addLabel("recent", using: &labelRanges)
                } else if i == TextOptionsList.PINNED_OPTIONS_COUNT {
                    addLabel(hrSeparatorText, using: &hrRanges)
                    addLabel("matched", using: &labelRanges)
                }
                let rangeStart = fullText.count
                fullText += "\n" + optionText
                optionRanges.append(NSRange(location: rangeStart + 1, length: optionText.count))
            }
            let attrText = NSMutableAttributedString(
                string: fullText,
                attributes: [
                    .font: NSFont.labelFont(ofSize: NSFont.systemFontSize),
                    .paragraphStyle: p
                ])
            storage.setAttributedString(attrText)
            
            for hrRange in hrRanges {
                storage.addAttributes(
                    [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: NSColor.separatorColor
                    ], range: hrRange)
            }
            for labelRange in labelRanges {
                storage.addAttributes(
                    [
                        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize * 0.9),
                        .foregroundColor: NSColor.systemGray,
                        .underlineColor: NSColor.systemGray,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ],
                    range: labelRange)
                storage.applyFontTraits(.italicFontMask, range: labelRange)
            }
            let fullTextNSString = NSString(string: fullText)
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
            callbacks.contentSizeChanged()
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
