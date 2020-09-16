// whatdidTests?

import XCTest
@testable import whatdid

class DelegatingSchedulerTest: XCTestCase {

    func testSingleTaskCanceled() {
        let dummy = DummyScheduler()
        let delegate = DelegatingScheduler(delegateTo: dummy)
        var count = 0
        
        let task = delegate.schedule("", after: 0) { count += 1 }
        XCTAssertEqual(1, delegate.tasksCount)
        XCTAssertEqual(0, count)
        
        task.cancel()
        XCTAssertEqual(0, delegate.tasksCount)
        XCTAssertEqual(0, count)
        
        dummy.runAllScheduled()
        XCTAssertEqual(0, count)
    }
    
    func testAllTasksCanceled() {
        let dummy = DummyScheduler()
        let delegate = DelegatingScheduler(delegateTo: dummy)
        var count = 0
        
        delegate.schedule("", after: 0) { count += 1 }
        XCTAssertEqual(1, delegate.tasksCount)
        XCTAssertEqual(0, count)
        
        delegate.close()
        XCTAssertEqual(0, delegate.tasksCount)
        XCTAssertEqual(0, count)
        
        dummy.runAllScheduled()
        XCTAssertEqual(0, count)
    }
    
    func testClosedSchedulerIgnoresNewTasks() {
        let dummy = DummyScheduler()
        let delegate = DelegatingScheduler(delegateTo: dummy)
        var count = 0
        
        delegate.close()
        XCTAssertEqual(0, delegate.tasksCount)
        XCTAssertEqual(0, count)
        
        delegate.schedule("", after: 0) { count += 1 }
        XCTAssertEqual(0, delegate.tasksCount)
        XCTAssertEqual(0, count)
        
        dummy.runAllScheduled()
        XCTAssertEqual(0, delegate.tasksCount)
        XCTAssertEqual(0, count)
    }
    
    func testSingleTaskRuns() {
        let dummy = DummyScheduler()
        let delegate = DelegatingScheduler(delegateTo: dummy)
        var count = 0
        
        delegate.schedule("", after: 0) { count += 1 }
        XCTAssertEqual(1, delegate.tasksCount)
        XCTAssertEqual(0, count)
        
        dummy.runAllScheduled()
        XCTAssertEqual(0, delegate.tasksCount)
        XCTAssertEqual(1, count)
    }
    
    func testSingleTaskRunsThenIsCanceled() {
        let dummy = DummyScheduler()
        let delegate = DelegatingScheduler(delegateTo: dummy)
        var count = 0
        
        let task = delegate.schedule("", after: 0) { count += 1 }
        XCTAssertEqual(1, delegate.tasksCount)
        XCTAssertEqual(0, count)
        
        dummy.runAllScheduled()
        XCTAssertEqual(0, delegate.tasksCount)
        XCTAssertEqual(1, count)
        
        task.cancel() // should be noop
        dummy.runAllScheduled()
        XCTAssertEqual(0, delegate.tasksCount)
        XCTAssertEqual(1, count)
    }
}
