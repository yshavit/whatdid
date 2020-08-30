// whatdid?

import Cocoa

extension NSStackView {
    convenience init(orientation: NSUserInterfaceLayoutOrientation) {
        self.init()
        useAutoLayout()
        self.orientation = orientation
    }
}
