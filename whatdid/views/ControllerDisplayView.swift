// whatdid?

import Cocoa

class ControllerDisplayView: NSBox {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wdViewInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wdViewInit()
    }
    
    func wdViewInit() {
        borderWidth = 0
        cornerRadius = 0
        boxType = .custom
        titlePosition = .noTitle
        contentViewMargins = .zero
    }
    
    @IBOutlet
    weak var controllerToDisplay: NSViewController? {
        didSet {
            contentView = controllerToDisplay?.view
        }
    }
}
