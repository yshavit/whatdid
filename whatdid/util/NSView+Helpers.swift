// whatdid?

import Cocoa

extension NSView {
    
    func anchorAllSides(to other: NSView) {
        useAutoLayout()
        topAnchor.constraint(equalTo: other.topAnchor).isActive = true
        leadingAnchor.constraint(equalTo: other.leadingAnchor).isActive = true
        bottomAnchor.constraint(equalTo: other.bottomAnchor).isActive = true
        trailingAnchor.constraint(equalTo: other.trailingAnchor).isActive = true
    }
    
    func useAutoLayout() {
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    func contains(pointInWindowCoordinates: NSPoint) -> Bool {
        let pointInSuperviewCoordinates = superview!.convert(pointInWindowCoordinates, from: nil)
        return frame.contains(pointInSuperviewCoordinates)
    }
}
