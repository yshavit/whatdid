// whatdid?

import Cocoa

struct DiagonalBoxFillHelper {
    /// The width of each individual stroke
    let strokeWidth: CGFloat
    /// The padding between strokes
    let strokePadding: CGFloat
    /// The angle, in degrees, of each stroke. This is measured as the angle between a vertical line segment and a stroke originating at the lower end
    /// of that segment.
    ///
    /// For example:
    /// ```
    /// ──┬──────
    ///   │  /
    ///   │𝛼/     𝛼 = strokeDegrees
    ///   │/
    /// ──┴────
    /// ```
    let strokeDegrees: CGFloat
    
    func diagonalLines(for dirtyRect: NSRect, within overallBounds: NSRect, draw: (LineSegment) -> Void) {
        guard strokeDegrees > 0 && strokeDegrees < 90 else {
            wdlog(.warn, "Couldn't draw strokes for angle %f because it has to be between 0 and 90 degrees")
            return
        }
        let actualDirty = overallBounds.intersection(dirtyRect)
        if actualDirty.isNull {
            return
        }
        /// SOH CAH TOA!
        /// Specifically, given the stroke angle `a`, `sin(a) = X / height`, where `X` is the offset we want.
        /// That means X = sin(a) * height
        let strokeRads = strokeDegrees * CGFloat.pi / 180
        let strokeOffset = sin(strokeRads) * overallBounds.height
        
        // Super dumb approach for now!
        // Start at X = (overallBounds.left - stroke). If we draw a stroke starting at that X and the overall bound's lower Y, such
        // a stroke would just barely hit the top-left of our overall bounds.
        // Keep going until X = (overallBounds.right + stroke): after that, lines are guaranteed to be outside the overall bounds.
        // Increment by padding.
        for strokeStartX in stride(from: overallBounds.minX - strokeOffset, through: overallBounds.maxX + strokeOffset, by: strokePadding) {
            if strokeStartX > actualDirty.maxX {
                // We've gone past the dirty rect; nothing more to do
                break
            }
            let strokeEndX = strokeStartX + strokeOffset
            if strokeEndX < actualDirty.minX {
                // We're not yet to the dirty rect; keep looping
                continue
            }
            let bottomLeft = NSPoint(x: strokeStartX, y: overallBounds.minY)
            let topRight = NSPoint(x: strokeEndX, y: overallBounds.maxY)
            // For now, don't even care about clipping.
            draw(LineSegment(a: bottomLeft, b: topRight))
        }
    }
    
    func drawDiagonalLines(for dirtyRect: NSRect, within overallBounds: NSRect) {
        let oldDefaultLineWidth = NSBezierPath.defaultLineWidth
        defer {
            NSBezierPath.defaultLineWidth = oldDefaultLineWidth
        }
        NSBezierPath.defaultLineWidth = strokeWidth
        
        diagonalLines(for: dirtyRect, within: overallBounds) {line in
            NSBezierPath.strokeLine(from: line.a, to: line.b)
        }
    }
    
    struct LineSegment {
        let a: NSPoint
        let b: NSPoint
    }
}
