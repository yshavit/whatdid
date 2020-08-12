// whatdidTests?

import XCTest
@testable import whatdid

class OpenCloseHelperTest: XCTestCase {

    func test_OpenAsManual_WhileClosed() throws {
        let (och, messages) = createTestObjects()
        
        och.open("one", reason: .manual)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([Message(shouldOpen: "one")], messages.drain())
        
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([], messages.drain())
    }
    
    func test_OpenAsScheduled_WhileClosed() {
        let (och, messages) = createTestObjects()
        
        och.open("one", reason: .scheduled)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([Message(shouldOpen: "one")], messages.drain())
        
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "one")], messages.drain())
    }
    
    func test_OneItem_OpenAsManual_WhileOpenedAsManual() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .manual))
        
        och.open("one", reason: .manual)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.didClose()
        // The second open request gets dropped entirely. See OpenCloserHelper.open for why.
        XCTAssertNil(och.openItem)
        XCTAssertEqual([], messages.drain())
    }

    func test_OneItem_OpenAsManual_WhileOpenedAsScheduled() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .scheduled))
        
        och.open("one", reason: .manual)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.didClose()
        // The second open request gets dropped entirely. See OpenCloserHelper.open for why.
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "one")], messages.drain())
    }

    func test_OneItem_OpenAsScheduled_WhileOpenedAsManual() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .manual))
        
        och.open("one", reason: .scheduled)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "one")], messages.drain())
    }

    func test_OneItem_OpenAsScheduled_WhileOpenedAsScheduled() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .scheduled))
        
        och.open("one", reason: .scheduled)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "one")], messages.drain())
    }

    func test_TwoItems_OpenAsManual_WhileOpenedAsManual() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .manual))
        
        och.open("two", reason: .manual)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.didClose()
        // The "two" request gets dropped entirely. See OpenCloserHelper.open for why.
        XCTAssertNil(och.openItem)
        XCTAssertEqual([], messages.drain())
    }

    func test_TwoItems_OpenAsManual_WhileOpenedAsScheduled() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .scheduled))
        
        och.open("two", reason: .manual)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.didClose()
        // The "two" request gets dropped entirely. See OpenCloserHelper.open for why.
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "one")], messages.drain())
    }

    func test_TwoItems_OpenAsScheduled_WhileOpenedAsManual() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .manual))
        
        och.open("two", reason: .scheduled)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.didClose()
        XCTAssertEqual("two", och.openItem)
        XCTAssertEqual([Message(shouldOpen: "two")], messages.drain())
        
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "two")], messages.drain())
    }

    func test_TwoItems_OpenAsScheduled_WhileOpenedAsScheduled() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .scheduled))
        
        och.open("two", reason: .scheduled)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.didClose()
        XCTAssertEqual("two", och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "one"), Message(shouldOpen: "two")], messages.drain())
        
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "two")], messages.drain())
    }
    
    func test_SnoozeDoesNotAffectManualOpens() {
        let (och, messages) = createTestObjects()
        
        och.snooze()
        
        och.open("one", reason: .manual)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([Message(shouldOpen: "one")], messages.drain())
        
        och.unSnooze()
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([], messages.drain())
    }
    
    func test_SnoozeDefersScheduledOpens() {
        let (och, messages) = createTestObjects()
        
        och.snooze()
        och.open("one", reason: .scheduled)
        XCTAssertNil(och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.unSnooze()
        XCTAssertEqual([Message(shouldOpen: "one")], messages.drain())
        XCTAssertEqual("one", och.openItem)
        
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "one")], messages.drain())
    }
    
    /// We have a window open, and then a snooze comes in, and then a scheduled open comes (with the first open still open)
    /// and causes a open-on-close. That open-on-close should be deferred until the snooze ends.
    func test_SnoozeWhileScheduledOpenGetsDeferred() {
        let (och, messages) = createTestObjects(alreadyOpened: ("one", .manual))
        
        och.snooze()
        
        och.open("two", reason: .scheduled)
        XCTAssertEqual("one", och.openItem)
        XCTAssertEqual([], messages.drain())
        
        // Close "one", but do *not* open "two"
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([], messages.drain())
        
        och.unSnooze()
        XCTAssertEqual("two", och.openItem)
        XCTAssertEqual([Message(shouldOpen: "two")], messages.drain())
        
        och.didClose()
        XCTAssertNil(och.openItem)
        XCTAssertEqual([Message(shouldSchedule: "two")], messages.drain())
        
    }
    
    func createTestObjects(alreadyOpened: (String, OpenReason)? = nil) -> (OpenCloseHelper<String>, Messages) {
        let messages = Messages()
        let och = OpenCloseHelper(onOpen: messages.open, onSchedule: messages.schedule)
        if let openAs = alreadyOpened {
            och.open(openAs.0, reason: openAs.1) // the scheduled-ness doesn't actually matter
            XCTAssertEqual([Message(shouldOpen: openAs.0)], messages.drain())
        }
        return (och, messages)
    }
    

    struct Message: Equatable {
        let item: String
        let shouldSchedule: Bool
        
        init(shouldSchedule item: String) {
            self.item = item
            self.shouldSchedule = true
        }
        
        init(shouldOpen item: String) {
            self.item = item
            self.shouldSchedule = false
        }
    }
    
    // Basically just a [String] but as a class, not struct.
    class Messages {
        
        private var messages = [Message]()
        
        func open(_ item: String) {
            messages.append(Message(shouldOpen: item))
        }
        
        func schedule(_ item: String) {
            messages.append(Message(shouldSchedule: item))
        }
        
        func drain() -> [Message] {
            let result = messages
            messages.removeAll()
            return result
        }
    }
}
