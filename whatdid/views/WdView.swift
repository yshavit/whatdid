// whatdid?

import Cocoa

@IBDesignable
class WdView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wdViewInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wdViewInit()
    }
    
    override final func prepareForInterfaceBuilder() {
        wdViewInit()
        super.prepareForInterfaceBuilder()
        initializeInterfaceBuilder()
        invalidateIntrinsicContentSize()
    }
    
    /// Initializes the view, regardless of which `init` overload it started with. The default implementation does nothing, and you do not need to call `super`.
    func wdViewInit() {
        // nothing
    }
    
    /// Initializes the view for the interface builder. The default implementation does nothing, and you do not need to call `super`.
    func initializeInterfaceBuilder() {
        // nothing
    }
}
