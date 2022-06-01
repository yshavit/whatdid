// whatdid?

import Cocoa

class SegmentedTimelineView: NSView {
    
    static let trackedProjectKey = "TRACKED_PROJECT"
    private static let boxFillhelper = DiagonalBoxFillHelper(strokeWidth: 1.0, strokePadding: 3.0, strokeDegrees: 30)
    
    private let strokeWidth = 2.0
    private var hoveredProject: String?
    private var explicitlyHighlightedProjects = Set<String>()
    private var segments = [Segment]()
    private var mostAncientDate: Date?
    private var mostRecentDate: Date?
    
    var onEnter: ((String) -> Void)?
    var onExit: ((String) -> Void)?
    
    var highlightedProjects: Set<String> {
        if let hoveredProject = hoveredProject {
            return explicitlyHighlightedProjects.union([hoveredProject])
        } else {
            return explicitlyHighlightedProjects
        }
    }
    
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
    
    func setEntries(_ entries: [FlatEntry]) {
        // group by project
        let byProject = Dictionary(grouping: entries, by: {$0.project})
        let segmentsByProject = byProject.mapValues(calculateSegments(from:))
        segments = segmentsByProject.values.flatMap({$0}).sorted(by: {$0.start < $1.start})
        mostAncientDate = segments.map({$0.start}).min()
        mostRecentDate = segments.map({$0.end}).max()
        updateTrackingAreas()
        setNeedsDisplay(bounds)
    }
    
    func highlightProject(named project: String) {
        updateHighlights {
            explicitlyHighlightedProjects.update(with: project)
        }
    }
    
    func unhighlightProject(named project: String) {
        updateHighlights {
            explicitlyHighlightedProjects.remove(project)
        }
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
        NSColor.gray.setStroke()
        SegmentedTimelineView.boxFillhelper.drawDiagonalLines(for: dirtyRect, within: bounds)
        NSBezierPath.defaultLineWidth = strokeWidth
        
        func drawLineAt(x: CGFloat) {
            if x >= dirtyRect.minX && x <= dirtyRect.maxX {
                NSColor.gray.setStroke()
                NSBezierPath.defaultLineWidth = 1
                NSBezierPath.strokeLine(from: NSPoint(x: x, y: dirtyRect.minY), to: NSPoint(x: x, y: dirtyRect.maxY))
                NSBezierPath.defaultLineWidth = strokeWidth
            }
        }
        
        // Draw the rects
        let currentlyHighlighted = highlightedProjects
        var lastBoundary: (CGFloat, Date)?
        forEntries {entry, entryRect in
            if let (lastXPos, lastEndDate) = lastBoundary, lastEndDate != entry.start {
                drawLineAt(x: lastXPos)
                drawLineAt(x: entryRect.minX)
            }
            lastBoundary = (entryRect.maxX, entry.end)
            let entryRectToDraw = entryRect.intersection(dirtyRect)
            if !entryRectToDraw.isNull {
                let isHighlighted = currentlyHighlighted.contains(entry.project)
                
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
        mouseEntered(with: event as ProjectTrackedEvent)
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseExited(with: event as ProjectTrackedEvent)
    }
    
    func mouseEntered(with event: ProjectTrackedEvent) {
        handle(event) {project in
            updateHighlights {
                hoveredProject = project
            }
        }
    }
    
    func mouseExited(with event: ProjectTrackedEvent) {
        handle(event) {project in
            updateHighlights {
                if hoveredProject == project {
                    hoveredProject = nil
                }
            }
        }
    }
    
    private func handle(_ event: ProjectTrackedEvent, via action: (String) -> Void) {
        guard let tracked = event.projectName else {
            wdlog(.warn, "failed to track mouse event in SegmentedTimelineView")
            return
        }
        action(tracked)
    }
    
    private func updateHighlights(via action: () -> Void) {
        let origHighlights = highlightedProjects
        action()
        let currHighlights = highlightedProjects
        toolTip = hoveredProject
        if origHighlights == currHighlights {
            return
        }
        if let onExit = onExit {
            let removedHighlights = origHighlights.filter { !currHighlights.contains($0) }
            removedHighlights.forEach(onExit)
        }
        if let onEnter = onEnter {
            let addedHighlights = currHighlights.subtracting(origHighlights)
            addedHighlights.forEach(onEnter)
        }
        setNeedsDisplay(bounds)
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

protocol ProjectTrackedEvent {
    var projectName: String? {
        get
    }
}

extension NSEvent: ProjectTrackedEvent {
    var projectName: String? {
        trackingArea?.userInfo?[SegmentedTimelineView.trackedProjectKey] as? String
    }
}
