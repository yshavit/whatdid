// whatdidTests?

import XCTest
@testable import whatdid

class SegmentedTimelineViewTest: XCTestCase {
    private let view = SegmentedTimelineView()
    private var seenEvents = [Event]()
    
    override func setUp() {
        view.onEnter = { self.seenEvents.append(.entered($0)) }
        view.onExit = { self.seenEvents.append(.exited($0)) }
    }
    
    func testNewlyInitialized() {
        XCTAssertEqual(strings(), view.highlightedProjects)
    }

    func testEventsEnterFiresFirst() {
        view.mouseEntered(with: MockEvent(affecting: "projectA"))
        XCTAssertEqual(strings("projectA"), view.highlightedProjects)
        checkEvents(expecting: .entered("projectA"))
        
        // First we'll fire an "enter" for projectB, and then an "exit" for projectA.
        view.mouseEntered(with: MockEvent(affecting: "projectB"))
        XCTAssertEqual(strings("projectB"), view.highlightedProjects)
        view.mouseExited(with: MockEvent(affecting: "projectA"))
        XCTAssertEqual(strings("projectB"), view.highlightedProjects)
        
        checkEvents(expecting: .exited("projectA"), .entered("projectB"))
    }
    
    func testEventsExitFiresFirst() {
        view.mouseEntered(with: MockEvent(affecting: "projectA"))
        XCTAssertEqual(strings("projectA"), view.highlightedProjects)
        checkEvents(expecting: .entered("projectA"))
        
        // First we'll fire an "exit" for projectA, and then an "enter" for projectB
        view.mouseExited(with: MockEvent(affecting: "projectA"))
        XCTAssertEqual(strings(), view.highlightedProjects)
        view.mouseEntered(with: MockEvent(affecting: "projectB"))
        XCTAssertEqual(strings("projectB"), view.highlightedProjects)
        
        checkEvents(expecting: .exited("projectA"), .entered("projectB"))
    }
    
    func testExplicitHighlighting() {
        view.highlightProject(named: "projectX")
        XCTAssertEqual(strings("projectX"), view.highlightedProjects)
        checkEvents(expecting: .entered("projectX"))
        
        view.highlightProject(named: "projectY")
        XCTAssertEqual(strings("projectX", "projectY"), view.highlightedProjects)
        checkEvents(expecting: .entered("projectY"))
        
        view.unhighlightProject(named: "projectX")
        XCTAssertEqual(strings("projectY"), view.highlightedProjects)
        checkEvents(expecting: .exited("projectX"))
        
        // unhighlight a second time; should be no-op
        view.unhighlightProject(named: "projectX")
        XCTAssertEqual(strings("projectY"), view.highlightedProjects)
        checkEvents()
        
        view.unhighlightProject(named: "projectY")
        XCTAssertEqual(strings(), view.highlightedProjects)
        checkEvents(expecting: .exited("projectY"))
    }
    
    func testExplicitlyHighlightedThenMouseIn() {
        // Highlight
        view.highlightProject(named: "projectA")
        XCTAssertEqual(strings("projectA"), view.highlightedProjects)
        checkEvents(expecting: .entered("projectA"))
        
        // Mouse-in should be no-op
        view.mouseEntered(with: MockEvent(affecting: "projectA"))
        XCTAssertEqual(strings("projectA"), view.highlightedProjects)
        checkEvents()
    }
    
    fileprivate func checkEvents(expecting expected: Event...) {
        XCTAssertEqual(expected, seenEvents)
        seenEvents.removeAll()
    }
    
    func strings(_ array: String...) -> Set<String> {
        return Set(array)
    }
    
    fileprivate struct MockEvent: ProjectTrackedEvent {
        let affecting: String
        
        var projectName: String? {
            get {
                affecting
            }
        }
    }
    
    fileprivate enum Event: Equatable {
        case entered(String)
        case exited(String)
    }
}
