// whatdid?

import Cocoa

class TextOptionsList: WdView, TextFieldWithPopupContents {
    private static let PINNED_OPTIONS_COUNT = 3
    
    private var textView: TrackingTextView!
    private var mouseoverHighlight: NSVisualEffectView!
    private var arrowSelectionHighlight: NSVisualEffectView!
    private var callbacks: TextFieldWithPopupCallbacks!
    private var heightConstraint: NSLayoutConstraint!
    /// This isn't just a performance-related cache: it's required for correctness.
    ///
    /// The system may call `accessibilityChildren()` several times, and if the elements haven't changed,
    /// it should return the same exact instances. This ensures that parent-child relationships and other such things
    /// all work correctly; I think it's also important for make sure that the objects don't get prematurely GC'ed, though
    /// I'm not positive about that.
    ///
    /// Point is, this is important!
    ///
    /// Alternatively, we could just calculate the array at each call to `updateText()`, and then just call
    /// `setAccessibilityChildren(~)`. This whole cache thing may be a premature optimization. But whatever,
    /// I've already written it!
    private var cachedAccessibilityChildren: [NSAccessibilityElement]?
    
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
    
    /// Updated from `updateText`, and then returned from `onTextChanged`
    private var autocompleteTo = ""
    
    var options = [String]() {
        didSet {
            updateText()
        }
    }
    
    var asView: NSView {
        self
    }
    
    /// Used for testing.
    ///
    /// You can generate the expected text using `DisplayTextBuilder`.
    var textViewText: NSAttributedString {
        return textView.attributedString()
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
        filterByText = newValue // triggers `updateText()`, which updates `autocompleteTo`
        return autocompleteTo
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
        
        heightConstraint = textView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.isActive = true
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
        
        textView.setAccessibilityElement(false)
        textView.setAccessibilityEnabled(false)
        setAccessibilityEnabled(true)
        setAccessibilityElement(true)
        setAccessibilityRole(.none)
        setAccessibilityLabel("Options")
        setAccessibilityChildren(nil)
    }
    
    override func initializeInterfaceBuilder() {
        options = ["alpha", "bravo", "charlie"]
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        cachedAccessibilityChildren = nil // invalidate so that we regenerate it as needed
    }
    
    override func accessibilityChildren() -> [Any]? {
        if let cachedAccessibilityChildren = cachedAccessibilityChildren {
            return cachedAccessibilityChildren
        }
        guard let window = window else {
            wdlog(.error, "no window to add accessibility elements to")
            return []
        }
        let textViewWidth = textView.bounds.width
        var results = [NSAccessibilityElement]()
        for (i, entry) in optionInfosByMinY.entries.enumerated() {
            let optionInfo = entry.value
            let textViewRect = NSRect(x: 0, y: optionInfo.minY, width: textViewWidth, height: optionInfo.maxY - optionInfo.minY)
            let windowRect = textView.convert(textViewRect, to: nil)
            let screenRect = window.convertToScreen(windowRect)
            let accessibility = NSAccessibilityElement.element(
                withRole: .staticText,
                frame: screenRect,
                label: optionInfo.stringValue,
                parent: self)
            if let accessibility = accessibility as? NSAccessibilityElement {
                accessibility.setAccessibilityIndex(i)
                accessibility.setAccessibilityRoleDescription("option")
                accessibility.setAccessibilityEnabled(true)
                accessibility.setAccessibilityFrameInParentSpace(textViewRect)
                results.append(accessibility)
            } else {
                wdlog(.error, "NSAccessibilityElement.element returned an unknown type; couldn't creaet accessibility element")
            }
        }
        cachedAccessibilityChildren = results
        return results
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
        cachedAccessibilityChildren = nil // invalidate so that we regenerate it as needed
        autocompleteTo = filterByText
        defer {
            if let layout = textView.layoutManager, let container = textView.textContainer {
                let fullRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
                heightConstraint.constant = layout.boundingRect(forGlyphRange: fullRange, in: container).height
            }
        }
        guard let storage = textView.textStorage, let pStyle = textView.defaultParagraphStyle else {
            textView.string = "<error>"
            wdlog(.error, "Couldn't find storage or default paragraph style")
            return
        }
        
        optionInfosByMinY.removeAll()
        if options.isEmpty {
            storage.setAttributedString(NSAttributedString(
                string: "(no previous entries)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .foregroundColor: NSColor.systemGray,
                    .underlineColor: NSColor.systemGray,
                ]))
            return
        }
        let builder = DisplayTextBuilder(paragraphStyle: pStyle)
        var optionRanges = [NSRange]()
        var italicRanges = [NSRange]()
        
        var haveShownMatchedLabel = false
        var autocomplete: String?
        for (i, optionText) in options.enumerated() {
            // Find the matches; continue to next iteration if there are none, and this isn't one of the top 3.
            let matched: [NSRange]
            if filterByText.isEmpty {
                matched = []
            } else {
                matched = SubsequenceMatcher.matches(lookFor: filterByText, inString: optionText)
                if matched.isEmpty && i >= TextOptionsList.PINNED_OPTIONS_COUNT {
                    continue
                }
            }
            // Add the section, if needed
            if i == 0 {
                italicRanges.append(builder.add(label: "recent"))
            } else if i >= TextOptionsList.PINNED_OPTIONS_COUNT && !haveShownMatchedLabel {
                builder.addHorizontalSeparator()
                italicRanges.append(builder.add(label: "matched"))
                haveShownMatchedLabel = true
            }
            // Add the option text
            optionRanges.append(builder.add(option: optionText, highlighting: matched))
            // Update the autocomplete, if applicable
            if optionText.starts(with: filterByText) {
                if let previousBest = autocomplete {
                    // Important not to inline these two ifs! The "else" below has
                    // to apply to only the first one.
                    if optionText.count < previousBest.count {
                        autocomplete = optionText
                    }
                } else {
                    autocomplete = optionText
                }
            }
        }
        autocompleteTo = autocomplete ?? filterByText
        storage.setAttributedString(builder.fullText)

        for labelRange in italicRanges {
            storage.applyFontTraits(.italicFontMask, range: labelRange)
        }
        let fullTextNSString = NSString(string: builder.fullText.string)
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
    
    class DisplayTextBuilder {
        private static let labelAttrs: [NSAttributedString.Key : Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize * 0.9),
            .foregroundColor: NSColor.systemGray,
            .underlineColor: NSColor.systemGray,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        private static let hrSeparatorAttrs: [NSAttributedString.Key : Any] = [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: NSColor.separatorColor
        ]
        private static let matchedCharAttrs: [NSAttributedString.Key : Any] = [
            .foregroundColor: NSColor.selectedTextColor,
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .underlineColor: NSColor.findHighlightColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        private static let hrSeparatorText = "\r\u{00A0}\u{0009}\u{00A0}\n" // https://stackoverflow.com/a/65994719/1076640.
        
        private let paragraphStyle: NSParagraphStyle
        let fullText = NSMutableAttributedString()
        
        init(paragraphStyle: NSParagraphStyle) {
            self.paragraphStyle = paragraphStyle
        }
        
        func add(option: String, highlighting matches: [NSRange]) -> NSRange {
            let _ = add(text: "\n", with: [:])
            let result =  add(text: option, with: [
                .font: NSFont.labelFont(ofSize: NSFont.systemFontSize),
                .paragraphStyle: paragraphStyle
            ])
            
            // Decorate it with the match info
            for match in matches {
                let adjustedRange = NSRange(location: match.location + result.location, length: match.length)
                fullText.addAttributes(DisplayTextBuilder.matchedCharAttrs, range: adjustedRange)
            }
            return result
        }
        
        func add(label: String) -> NSRange {
            return add(text: label, with: DisplayTextBuilder.labelAttrs)
        }
        
        func addHorizontalSeparator() {
            let _ = add(text: DisplayTextBuilder.hrSeparatorText, with: DisplayTextBuilder.hrSeparatorAttrs)
        }
        
        private func add(text: String, with attributes: [NSAttributedString.Key : Any]) -> NSRange {
            let range = NSRange(location: fullText.length, length: text.count)
            fullText.append(NSAttributedString(string: text, attributes: attributes))
            return range
        }
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
