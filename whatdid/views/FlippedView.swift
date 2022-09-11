// whatdid?

import Cocoa

class FlippedView: WdView {

    override var isFlipped : Bool {
        get {
            return true
        }
    }
    
    static func of(_ view: NSView) -> NSView {
        let result = FlippedView()
        result.addSubview(view)
        result.anchorAllSides(to: view)
        return result
    }
}
