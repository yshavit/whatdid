// whatdid?

import Cocoa
import SwiftUI

class SegmentedTimelineView: NSView {
    
    private static let trackedProjectKey = "TRACKED_PROJECT"
    
    private let strokeWidth = 2.0
    private var highlightedProject: String?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        doInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        doInit()
    }
    
    private func doInit() {
        heightAnchor.constraint(greaterThanOrEqualToConstant: 10).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
    }
    
    private var segments = [Segment]()
    private var mostAncientDate: Date?
    private var mostRecentDate: Date?
    
    func setEntries(_ entries: [FlatEntry]) {
        // group by project
        let byProject = Dictionary(grouping: entries, by: {$0.project})
        let segmentsByProject = byProject.mapValues(calculateSegments(from:))
        segments = segmentsByProject.values.flatMap({$0})
        mostAncientDate = segments.map({$0.start}).min()
        mostRecentDate = segments.map({$0.end}).max()
        updateTrackingAreas()
        setNeedsDisplay(bounds)
    }
    
    private func calculateSegments(from entries: [FlatEntry]) -> [Segment] {
        var segments = [Segment]()
        for entry in entries {
            if let current = segments.last, entry.from <= current.end {
                current.end = entry.to
            } else {
                segments.append(Segment(from: entry))
            }
        }
        return segments
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Clear out the background
        // TODO should consider adding an angled stripe pattern here, for missing segments
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath.fill(dirtyRect)
        NSBezierPath.defaultLineWidth = strokeWidth
        
        // Draw the rects
        forEntries {entry, entryRect in
            let entryRectToDraw = entryRect.intersection(dirtyRect)
            if !entryRectToDraw.isNull {
                let isHighlighted = highlightedProject == entry.project
                
                var color = color(for: entry.project)
                if !isHighlighted {
                    NSColor.lightGray.setFill()
                    NSBezierPath.fill(entryRectToDraw)
                    color = color.withAlphaComponent(0.65)
                }
                color.setFill()
                NSBezierPath.fill(entryRectToDraw)
                
                if isHighlighted {
                    let inverseColor = NSColor(
                        red: 1 - color.redComponent,
                        green: 1 - color.greenComponent,
                        blue: 1 - color.blueComponent,
                        alpha: 1.0)
                    inverseColor.setStroke()
                    NSBezierPath.stroke(entryRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2))
                }
            }
        }
        
        // Now the overall outline
        NSColor.darkGray.setStroke()
        NSBezierPath.defaultLineWidth = 1.0
        NSBezierPath.stroke(bounds)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea(_:))
        forEntries {entry, entryRect in
            addTrackingArea(NSTrackingArea(
                rect: entryRect,
                options: [.mouseEnteredAndExited, .activeAlways],
                owner: self,
                userInfo: [SegmentedTimelineView.trackedProjectKey: entry.project]))
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        withEvent(for: event, {highlightedProject = $0})
    }
    
    override func mouseExited(with event: NSEvent) {
        withEvent(for: event, {
            if highlightedProject == $0 {
                highlightedProject = nil
            }
        })
    }
    
    private func withEvent(for event: NSEvent, _ block: (String) -> Void) {
        if let tracked = event.trackingArea?.userInfo?[SegmentedTimelineView.trackedProjectKey] as? String {
            block(tracked)
            setNeedsDisplay(bounds)
        }
        toolTip = highlightedProject
    }
    
    private func forEntries(_ block: (Segment, NSRect) -> Void) {
        guard let mostRecentDate = mostRecentDate, let mostAncientDate = mostAncientDate else {
            wdlog(.debug, "No recent or ancient date; is \"entries\" empty?")
            return
        }
        let overallTimeAmount = mostRecentDate.timeIntervalSince(mostAncientDate)
        func xPos(for interval: TimeInterval) -> Double {
            let intervalAsRatio = interval / overallTimeAmount
            return intervalAsRatio * bounds.width
        }
        let bounds = bounds
        for segment in segments {
            let entryRect = NSRect(
                x: xPos(for: segment.start.timeIntervalSince(mostAncientDate)),
                y: bounds.minY,
                width: xPos(for: segment.end.timeIntervalSince(segment.start)),
                height: bounds.height)
            block(segment, entryRect)
        }
    }
    
    func color(for string: String) -> NSColor {
        let hashUInt = UInt32(truncatingIfNeeded: string.hashValue)
        let rand = SimpleRandom(seed: hashUInt)
        return NSColor(
            red: CGFloat(rand.nextUnitFloat()),
            green: CGFloat(rand.nextUnitFloat()),
            blue: CGFloat(rand.nextUnitFloat()),
            alpha: 1.0)
    }
    
    private class Segment {
        let project: String
        let start: Date
        var end: Date
        
        init(from entry: FlatEntry) {
            project = entry.project
            start = entry.from
            end = entry.to
        }
    }
}
