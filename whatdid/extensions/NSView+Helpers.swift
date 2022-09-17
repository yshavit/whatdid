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
            func p(_ elem: Any) {
                print(String(repeating: "    ", count: indent), elem, separator: "")
            }
            let excuse = view.constraints.isEmpty && view.subviews.isEmpty ? " (no constraints or subviews)" : ""
            p(view.className + excuse)
            if excuse.isEmpty {
                p(String(repeating: "─", count: view.className.count))
            }
            for c in view.constraintsAffectingLayout(for: .horizontal) {
                p("↔︎ \(c)")
            }
            for c in view.constraintsAffectingLayout(for: .vertical) {
                p("↕︎ \(c)")
            }
            print("")
            for v in view.subviews {
                doPrint(view: v, indent: indent + 1)
            }
        }
        doPrint(view: self, indent: 0)
    }
    #endif
}
