// whatdid?

import Cocoa

extension NSTextField {
    func flashTextField() {
        let animation = TextFlasherAnimation()
        animation.flash(field: self)   
    }
}

private class TextFlasherAnimation {
    typealias PlaceholderInfo = (NSAttributedString, [NSAttributedString.Key:Any], NSColor)
    
    private var isFlashingIn = true
    
    private static var inProgressFields = Atomic<Set<NSTextField>>(wrappedValue: Set())
    
    /// Flashes the placeholder text to red and back.
    ///
    /// The "and back" bit has an interesting wrinkle: if you were to flash this while a previous animation is still going on, the second flash would
    /// think its target is the first animation's partial state; so that second animation would go from that partial state, to red, back to that partial state.
    /// That would make the red-ness sticky, which we don't want. To get around that, we maintain a static, atomic set of all in-progress fields, and
    /// use this from blocking duplicates.
    func flash(field: NSTextField) {
        var isAlreadyAnimating = false
        TextFlasherAnimation.inProgressFields.modifyInPlace {set in
            let (wasInserted, _) = set.insert(field)
            isAlreadyAnimating = !wasInserted
        }
        if isAlreadyAnimating {
            return
        }
        guard let (_, _, originalColor) = TextFlasherAnimation.getPlaceholderAndColor(on: field) else {
            return
        }
        PlaceholderAnimation().flashPlaceholder(field: field, to: .red, over: 0.1) {
            PlaceholderAnimation().flashPlaceholder(field: field, to: originalColor, over: 0.3) {
                TextFlasherAnimation.inProgressFields.modifyInPlace {set in
                    set.remove(field)
                }
            }
        }
    }
    
    private static func getPlaceholderAndColor(on field: NSTextField) -> PlaceholderInfo? {
        guard let placeholder = field.placeholderAttributedString else {
            return nil
        }
        let attributes = placeholder.attributes(at: 0, effectiveRange: nil)
        guard let placeholderColor = attributes[.foregroundColor] as? NSColor else {
            return nil
        }
        return (placeholder, attributes, placeholderColor)
    }
    
    private class PlaceholderAnimation: NSAnimation, NSAnimationDelegate {
        private var field: NSTextField!
        private var targetColor: NSColor!
        private var origPlaceholder: NSAttributedString!
        private var origColor: NSColor!
        private var attributes: [NSAttributedString.Key : Any]!
        private var onComplete: Action!
        
        func flashPlaceholder(field: NSTextField, to target: NSColor, over: TimeInterval, andThen onComplete: @escaping Action) {
            guard let (placeholder, attributes, placeholderColor) = TextFlasherAnimation.getPlaceholderAndColor(on: field) else {
                return
            }
            self.origPlaceholder = placeholder
            self.attributes = attributes
            self.origColor = placeholderColor
            self.field = field
            
            self.targetColor = target
            self.duration = over
            self.animationBlockingMode = .nonblocking
            self.delegate = self
            self.onComplete = onComplete
            
            self.start()
        }
        
        override var currentProgress: NSAnimation.Progress {
            get { super.currentProgress }
            set (value) {
                let newColor = origColor.blended(withFraction: CGFloat(value), of: targetColor)
                attributes[.foregroundColor] = newColor
                field.placeholderAttributedString = NSAttributedString(string: origPlaceholder.string, attributes: attributes)
                super.currentProgress = value
            }
        }

        func animationDidEnd(_ animation: NSAnimation) {
            onComplete()
        }
    }
}
