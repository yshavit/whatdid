// whatdid?

import Cocoa

class TextOptionsList: WdView, TextFieldWithPopupContents {
    fileprivate static let PINNED_OPTIONS_COUNT = 3
    
    var callbacks: TextFieldWithPopupCallbacks!
    
    var asView: NSView {
        self
    }
    
    func willShow(callbacks: TextFieldWithPopupCallbacks) {
        self.callbacks = callbacks
    }
    
    func moveSelection(_ direction: Direction) {
        #warning("TODO")
        wdlog(.info, "TextOptionsList moving selection %@", direction == .up ? "up" : "down")
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
    
    func handleClick(at point: NSPoint) -> String? {
        let y = textView.frame.height - point.y // textField's coordinates are inverted from the optionInfosByMaxY's
        return optionInfosByMaxY.find(highestEntryLessThanOrEqualTo: y)?.stringValue
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
        
        scrollHighlightOverlay = NSVisualEffectView()
        
        textView.wantsLayer = true
        textView.drawsBackground = false
        
        addSubview(scrollHighlightOverlay)
//        addSubview(FlippedView.of(textView))
        addSubview(textView)
        textView.anchorAllSides(to: self)
    }
    
    override func initializeInterfaceBuilder() {
        #warning("TODO")
    }
    
    //--------------------------------------------------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------------------------------------//
    //--------------------------------------------------------------------------------------------------------------------------//
    private var textView: TrackingTextView!
    private var scrollHighlightOverlay: NSVisualEffectView!
    
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

    private var optionInfosByMaxY = SortedMap<CGFloat, OptionInfo>()
    
    private func trackMouseMovement(_ point: NSPoint?) {
        if let point = point {
            if let highlighted = optionInfosByMaxY.find(highestEntryLessThanOrEqualTo: point.y) {
                // The textField's coordinates are 0-on-top, whereas these coordinates are 0-on-bottom. So, flip 'em.
                let y = textView.frame.height - highlighted.maxY
                scrollHighlightOverlay.frame = NSRect(
                    x: 0,
                    y: y,
                    width: textView.bounds.width,
                    height: highlighted.maxY - highlighted.minY)
                scrollHighlightOverlay.isHidden = false
            }
        } else {
            scrollHighlightOverlay.isHidden = true
        }
    }

    
    var options: [String] {
        get {
            return optionInfosByMaxY.entries.map { $0.value.stringValue }
        }
        set (values) {
            optionInfosByMaxY.removeAll()
            if values.isEmpty {
                let labelString = NSAttributedString(string: "(no previous entries)", attributes: [
                    NSAttributedString.Key.foregroundColor: NSColor.systemGray,
                ])
                textView.string = "(no previous entries)"
                textView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                return
            }
            var fullText = ""
            var optionRanges = [NSRange]()
            #warning("todo add separator")
            for (i, optionText) in values.enumerated() {
                let rangeStart: Int
                if fullText.isEmpty {
                    rangeStart = 0
                } else {
                    fullText += "\n"
                    rangeStart = fullText.count
                }
                fullText += optionText
                optionRanges.append(NSRange(location: rangeStart, length: optionText.count))
                
                if let storage = textView.textStorage, let p = textView.defaultParagraphStyle {
                    #warning("TODO use consts for both font and graf style")
                    let font = NSFont.labelFont(ofSize: NSFont.systemFontSize)
                    let attrText = NSAttributedString(
                        string: fullText,
                        attributes: [
                            .font: font,
                            .paragraphStyle: p
                        ])
                    storage.setAttributedString(attrText)
                }
            }
            let fullTextNSString = NSString(string: fullText)
                
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                var optionInfoEntries = [(CGFloat, OptionInfo)]()
                layoutManager.ensureLayout(for: textContainer)
                let f = layoutManager.usedRect(for: textContainer)
                let size = f.size
                textView.frame = f
                wdlog(.info, "layout size: %@", size as CVarArg)
                for (pCount, p) in optionRanges.enumerated() {
                    // see https://stackoverflow.com/questions/2654580/how-to-resize-nstextview-according-to-its-content
                    var rectCount = -1
                    let rects = layoutManager.rectArray(
                        forCharacterRange: p,
                        withinSelectedCharacterRange: p,
                        in: textContainer,
                        rectCount: &rectCount)
                    var yBounds: (CGFloat, CGFloat)?
                    if let rects = rects {
                        for i in 0..<rectCount {
                            let rect = rects[i]
                            let (currMinY, currMaxY) = yBounds ?? (rect.minY, rect.maxY) // if nil, just use the current rect; min/max are identities in that case
                            yBounds = (
                                min(currMinY, rect.minY),
                                max(currMaxY, rect.maxY)
                            )
                        }
                    }
                    if let (minY, maxY) = yBounds {
                        let optionText = fullTextNSString.substring(with: p)
                        optionInfoEntries.append((minY, OptionInfo(minY: minY, maxY: maxY, stringValue: optionText)));
                    } else {
                        wdlog(.warn, "Couldn't find maxY for option #%d", pCount)
                    }
                }
                optionInfosByMaxY.add(kvPairs: optionInfoEntries)
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
