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
    
    #if UI_TEST
    func printConstraints() {
        func doPrint(view: NSView, indent: Int) {
            let h = String(repeating: "    ", count: indent)
            print("\(h)* \(view.className):")
            for c in view.constraints.filter({$0.isActive}) {
                print("\(h)\(view.className): \(c)")
            }
            for v in view.subviews {
                doPrint(view: v, indent: indent + 1)
            }
            
        }
        doPrint(view: self, indent: 0)
    }
    #endif
}
