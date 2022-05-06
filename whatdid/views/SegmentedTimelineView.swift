// whatdid?

import Cocoa
import SwiftUI

class SegmentedTimelineView: NSView {
    
    private static let trackedProjectKey = "TRACKED_PROJECT"
    
    private let strokeWidth = 2.0
    private var highlightedProjects = Set<String>()
    
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
    
    var entries = [FlatEntry]() {
        didSet {
            entries.sort(by: { $0.from < $1.from })
            mostRecentDate = entries.map({$0.to}).max()
            updateTrackingAreas()
        }
    }
    private var mostRecentDate: Date?

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
                let isHighlighted = highlightedProjects.contains(entry.project)
                
                var color = entry.project.hashToColor
                if !isHighlighted {
                    NSColor.white.setFill()
                    NSBezierPath.fill(entryRectToDraw)
                    color = color.withAlphaComponent(0.85)
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
        withEvent(for: event, {highlightedProjects.update(with: $0)})
    }
    
    override func mouseExited(with event: NSEvent) {
        withEvent(for: event, {highlightedProjects.remove($0)})
    }
    
    private func withEvent(for event: NSEvent, _ block: (String) -> Void) {
        if let tracked = event.trackingArea?.userInfo?[SegmentedTimelineView.trackedProjectKey] as? String {
            block(tracked)
            setNeedsDisplay(bounds)
        }
        toolTip = highlightedProjects.first
    }
    
    private func forEntries(_ block: (FlatEntry, NSRect) -> Void) {
        guard let mostRecentDate = mostRecentDate, let mostAncientDate = entries.first?.from else {
            wdlog(.debug, "No recent or ancient date; is \"entries\" empty?")
            return
        }
        let overallTimeAmount = mostRecentDate.timeIntervalSince(mostAncientDate)
        func xPos(for interval: TimeInterval) -> Double {
            let intervalAsRatio = interval / overallTimeAmount
            return intervalAsRatio * bounds.width
        }
        let bounds = bounds
        for entry in entries {
            let entryRect = NSRect(
                x: xPos(for: entry.from.timeIntervalSince(mostAncientDate)),
                y: bounds.minY,
                width: xPos(for: entry.to.timeIntervalSince(entry.from)),
                height: bounds.height)
            block(entry, entryRect)
        }
    }
}
