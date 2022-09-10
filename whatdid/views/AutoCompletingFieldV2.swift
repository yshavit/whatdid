// whatdid?

import Cocoa

class AutoCompletingFieldV2: WdView {

    /// Invoked when the user hits "enter" after typing text; or when they click on an option to select it.
    var action: (AutoCompletingFieldV2) -> Void = {_ in}
    // The underlying data for the options
    var optionsLookup: (() -> [String])?
    // Invoked as the user types, or arrows to different options.
    var onTextChange: (() -> Void) = {}
    // Invoked when the user escapes out of the field.
    var onCancel: (() -> Void) = { }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func wdViewInit() {
    }
    
}
