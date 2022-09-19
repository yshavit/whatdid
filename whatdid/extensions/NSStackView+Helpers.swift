// whatdid?

import Cocoa

extension NSStackView {
    convenience init(orientation: NSUserInterfaceLayoutOrientation, _ with: NSView...) {
        self.init()
        useAutoLayout()
        self.orientation = orientation
        with.forEach(self.addArrangedSubview(_:))
    }
}
