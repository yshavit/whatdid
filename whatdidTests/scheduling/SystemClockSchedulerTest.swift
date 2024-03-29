// whatdidTests?

import XCTest
@testable import Whatdid

class SystemClockSchedulerTest: XCTestCase {
    private static let delay = TimeInterval(5)
    
    static let scheduler = SystemClockScheduler()

    /// A single test for all checks. Since the tests have a delay (and need it, since we're testing schedules), this lets us save wall-clock time by
    /// doing them all in parallel.
    func testScheduling() {
        let checks = XCTContext.runActivity(named: "create checks") {(XCTActivity) -> [SingleCheck] in
            let checks = DelayStrategy.allCases.flatMap{[($0, true), ($0, false)]}.map{SingleCheck(delay: $0.0, willBeCanceled: $0.1)}
            XCTAssertEqual(4, checks.count) // sanity check
            
            checks.forEach { $0.start() }
            sleep(1)
            checks.forEach { XCTAssertFalse($0.timerFired) }
            checks.filter{$0.shouldGetCanceled}.forEach {check in
                XCTAssertNotNil(check.scheduledTask, check.description)
                check.scheduledTask?.cancel()
            }
            return checks
        }
        XCTContext.runActivity(named: "wait for checks to run") {_ in
            print("Waiting for checks to run")
            wait(for: checks.compactMap{$0.expectation}, timeout: SystemClockSchedulerTest.delay * 2)
            sleep(1) // If any canceled tasks were going to happen, this gives them time to happen
        }
        XCTContext.runActivity(named: "check results") {_ in
            checks.forEach {check in
                XCTAssertEqual(check.shouldGetCanceled, !check.timerFired, check.description)
            }
        }
    }
    
    func testCancelTaskAfterItRuns() {
        let expectation = XCTestExpectation()
        var count = 0
        let scheduledTask = SystemClockSchedulerTest.scheduler.schedule("", after: 0.1) {
            count += 1
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(1, count)
        
        scheduledTask.cancel() // should be noop
        XCTAssertEqual(1, count)
    }
    
    func testTaskScheduledInPast() {
        let taskCompletion = XCTestExpectation(description: "task to be run")
        _ = SystemClockSchedulerTest.scheduler.schedule("", after: -10000) {
            taskCompletion.fulfill()
        }
        wait(for: [taskCompletion], timeout: 10)
    }
    
    func testNoLeaks() {
        var expectations = [XCTestExpectation]()
        for _ in 0..<100 {
            let taskCompletion = XCTestExpectation()
            expectations.append(taskCompletion)
            _ = SystemClockSchedulerTest.scheduler.schedule("", after: 1.5) {
                taskCompletion.fulfill()
            }
        }
        // We should have at least a few tasks still in their 1.5 second waiting period
        XCTAssertGreaterThan(SystemClockSchedulerTest.scheduler.approximatePendingTasksCount, 0)
        wait(for: expectations, timeout: 10)
        // But now that they've all completed, they should all be cleared from memory
        XCTAssertEqual(0, SystemClockSchedulerTest.scheduler.approximatePendingTasksCount)
        
    }
    
    class SingleCheck: CustomStringConvertible {
        private let delayStrategy: DelayStrategy
        var timerFired = false
        let expectation: XCTestExpectation?
        let description: String
        let shouldGetCanceled: Bool
        var scheduledTask: ScheduledTask?
        
        init(delay: DelayStrategy, willBeCanceled: Bool) {
            self.delayStrategy = delay
            self.shouldGetCanceled = willBeCanceled
            
            let delayDesc = String(describing: delayStrategy)
            let expectedDesc = shouldGetCanceled ? "will be canceled" : "will not be canceled"
            description = "\(delayDesc) \(expectedDesc)"
            self.expectation = shouldGetCanceled ? nil : XCTestExpectation()
        }
        
        func start(){
            switch delayStrategy {
            case .byDate:
                scheduledTask = SystemClockSchedulerTest.scheduler.schedule("", at: Date().addingTimeInterval(SystemClockSchedulerTest.delay), setResult)
            case .byInterval:
                scheduledTask = SystemClockSchedulerTest.scheduler.schedule("", after: SystemClockSchedulerTest.delay, setResult)
            }
        }
        
        private func setResult() {
            timerFired = true
            expectation?.fulfill()
        }
    }
    
    enum DelayStrategy: CaseIterable {
        case byInterval
        case byDate
    }

}
