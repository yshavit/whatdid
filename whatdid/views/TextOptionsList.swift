// whatdid?

import Cocoa

class TextOptionsList: WdView, TextFieldWithPopupContents {
    /// Characters to ignore when reporting the accessibility value
    var accessibilityStringIgnoredChars = CharacterSet()
    
    var emptyOptionsPlaceholder = "(no previous entries)"
    
    private static let PINNED_OPTIONS_COUNT = 3
    
    private var textView: TrackingTextView!
    private var mouseoverHighlight: NSVisualEffectView!
    private var arrowSelectionHighlight: NSVisualEffectView!
    private var callbacks: TextFieldWithPopupCallbacks!
    private var heightConstraint: NSLayoutConstraint!
    
    private var selectionIdx: Int? {
        didSet {
            updateSelection()
        }
    }
    
    var selectedText: String? {
        selectionIdx.map({optionInfosByMinY.entries[$0].value.stringValue})
    }
    
    private var filterByText = "" {
        didSet {
            let oldSelected: (String, Int)? // the old text, and how many duplicates of that text were before it
            if let selectionIdx = selectionIdx {
                let allOptions = optionInfosByMinY.entries.map({$0.value.stringValue})
                let oldText = allOptions[selectionIdx]
                let entriesBeforeSelection = allOptions[0..<selectionIdx]
                let dupesCount = entriesBeforeSelection.filter({$0 == oldText}).count
                oldSelected = (oldText, dupesCount)
            } else {
                oldSelected = nil
            }
            updateText()
            if let (oldText, oldDupesCount) = oldSelected {
                /// `updateText()` cleared the selection. We may want to restore it. There are a few scenarios:
                ///
                /// 1. Current `filterByText` starts with `oldValue`: the user typed additional characters.
                /// 2. The `oldValue` starts with `filterByText`: the user deleted characters.
                /// 3. Alll other cases (we're not interested in common prefixes, etc).
                ///
                /// The first case is tricky, because our selected option may not be available anymore. If it's not, where should we go instead? Do we pick
                /// the next-best option, even if it may be far away from where the original was? Since elements aren't ordered, can we shift _up_?
                ///
                /// The easy case is when the old selected option is still available. In that case, stay on it. For now, let's say that in all other cases, we just
                /// unselect.
                ///
                /// In case #2, we know the old option is still available; so let's stay on it.
                ///
                /// In case 3, we should just clear the selection.
                ///
                /// tldr: If the old option is still available, stay on it, otherwise clear the selection.
                ///
                /// This may not always be the most convenient, but it's nice and simple, and doesn't risk the user jumping all around as they type.
                /// As an added bonus: an option may be present multiple times. Let's stay on whichever one we were at before (they'll all be there, or none be there).
                let allOptions = optionInfosByMinY.entries.map({$0.value.stringValue})
                var dupesRemaining = oldDupesCount
                for (i, optionText) in allOptions.enumerated() {
                    if optionText == oldText {
                        if dupesRemaining == 0 {
                            selectionIdx = i
                            break
                        } else {
                            dupesRemaining -= 1
                        }
                    }
                }
            }
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
    
    func didHide() {
        selectionIdx = nil
    }
    
    func moveSelection(_ direction: Direction) {
        let allEntries = optionInfosByMinY.entries
        guard !allEntries.isEmpty else {
            selectionIdx = nil
            return
        }
        let largestIdx = allEntries.count - 1
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
            /// Okay, this is a special case! We want the first hit that matches, but if none do, then we want just element 0.
            /// We're guaranteed a match at element index `PINNED_OPTIONS_COUNT` + 1 (ie the 4th element, if we pin 3).
            /// So, look for at least `PINNED_OPTIONS_COUNT + 1` elems (but to a max of however many there are, obviously!),
            /// and if you don't find any, then in _that_ case fall back to `0.`
            idx = 0
            /// Special case: if `filterByText.isEmpty`, then the 0th will always match.
            if !filterByText.isEmpty {
                for i in 0..<min(TextOptionsList.PINNED_OPTIONS_COUNT + 1, allEntries.count) {
                    let optionText = optionInfosByMinY.entries[i].value.stringValue
                    let matches = SubsequenceMatcher.matches(lookFor: filterByText, inString: optionText)
                    if !matches.isEmpty {
                        idx = i
                        break
                    }
                }
            }
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
        grafStyle.alignment = .natural
        textView.defaultParagraphStyle = grafStyle
        
        heightConstraint = textView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.isActive = true
        textView.mouseMoved = trackMouseMovement(_:)
        textView.startTracking()
        
        mouseoverHighlight = NSVisualEffectView()
        arrowSelectionHighlight = NSVisualEffectView()
        arrowSelectionHighlight.isEmphasized = true
        for highlight in [mouseoverHighlight, arrowSelectionHighlight] {
            highlight!.state = .active
            highlight!.material = .selection
            highlight!.blendingMode = .behindWindow
        }
        
        textView.wantsLayer = true
        textView.drawsBackground = false
        
        addSubview(mouseoverHighlight)
        addSubview(arrowSelectionHighlight)
        addSubview(textView)
        textView.anchorAllSides(to: self)
        
        textView.setAccessibilityElement(false)
        textView.setAccessibilityEnabled(false)
        textView.setAccessibilityRole(.list)
        textView.setAccessibilityLabel("Options")
        
        updateText()
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
        selectionIdx = nil // TODO maybe keep it iff the new option is still available?
        autocompleteTo = filterByText
        defer {
            if let layout = textView.layoutManager, let container = textView.textContainer {
                let fullRange = layout.glyphRange(for: container)
                let requestedHeight = layout.boundingRect(forGlyphRange: fullRange, in: container).height
                if heightConstraint.constant != requestedHeight {
                    heightConstraint.constant = requestedHeight
                    callbacks?.contentSizeChanged()
                }
            }
            let accessibilityChildren = (0..<optionInfosByMinY.entries.count).map {
                OptionAccessibilityElement(parent: self, optionIndex: $0)
            }
            textView.setAccessibilityChildren(accessibilityChildren)
        }
        guard let storage = textView.textStorage, let pStyle = textView.defaultParagraphStyle else {
            textView.string = "<error>"
            wdlog(.error, "Couldn't find storage or default paragraph style")
            return
        }
        optionInfosByMinY.removeAll()
        if options.isEmpty {
            
            storage.setAttributedString(NSAttributedString(
                string: emptyOptionsPlaceholder,
                attributes: [
                    .font: NSFont.labelFont(ofSize: NSFont.smallSystemFontSize),
                    .paragraphStyle: NSParagraphStyle.default,
                    .foregroundColor: NSColor.disabledControlTextColor,
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
    
    private class OptionAccessibilityElement: NSAccessibilityElement {
        private let parent: TextOptionsList
        private let optionIndex: Int
        
        init(parent: TextOptionsList, optionIndex: Int) {
            self.parent = parent
            self.optionIndex = optionIndex
            super.init()
            setAccessibilityRole(.textField)
            var value = parent.optionInfosByMinY.entries[optionIndex].value.stringValue
            value.unicodeScalars.removeAll(where: parent.accessibilityStringIgnoredChars.contains(_:))
            setAccessibilityValue(value)
            setAccessibilityLabel(accessibilityValue() as? String)
            setAccessibilityIndex(optionIndex)
            setAccessibilityRoleDescription("option")
            setAccessibilityEnabled(true)
            setAccessibilityElement(true)
        }
        
        override func isAccessibilitySelected() -> Bool {
            return parent.selectionIdx == optionIndex
        }
        
        override func accessibilityFrame() -> NSRect {
            let optionInfo = parent.optionInfosByMinY.entries[optionIndex].value
            let width = parent.textView.frame.width
            let textViewRect = NSRect(x: 0, y: optionInfo.minY, width: width, height: optionInfo.maxY - optionInfo.minY)
            
            let windowRect = parent.textView.convert(textViewRect, to: nil)
            let screenRect = parent.textView.window?.convertToScreen(windowRect) ?? NSRect.zero
            return screenRect
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
        
        var optionAttrs: [NSAttributedString.Key : Any] {
            return [
                .font: NSFont.labelFont(ofSize: NSFont.systemFontSize),
                .paragraphStyle: paragraphStyle,
            ]
        }
        
        func add(option: String, highlighting matches: [NSRange]) -> NSRange {
            let _ = add(text: "\n", with: [:])
            let result =  add(text: option, with: optionAttrs)
            
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
