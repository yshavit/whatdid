// whatdidUITests?

import XCTest

extension XCTestCase {
    class func group<R>(_ name: String, _ block: () -> R) -> R {
        return XCTContext.runActivity(named: name, block: {_ in return block()})
    }
    
    class func sleepMillis(_ ms: Int) {
        usleep(useconds_t(ms * 1000))
    }
    
    func sleepMillis(_ ms: Int) {
        XCTestCase.sleepMillis(ms)
    }
    
    func group<R>(_ name: String, _ block: () -> R) -> R {
        return XCTestCase.group(name, block)
    }
    
    func wait(timeout: TimeInterval = 5, pollEvery delay: TimeInterval = 0.25, for description: String, until condition: () -> Bool) {
        XCTestCase.wait(timeout: timeout, pollEvery: delay, for: description, until: condition)
    }
    
    class func wait(timeout: TimeInterval = 5, pollEvery delay: TimeInterval = 0.25, for description: String, until condition: () -> Bool) {
        let tryUntil = Date().addingTimeInterval(timeout)
        while true {
            if condition() {
                return
            }
            XCTAssertLessThan(Date(), tryUntil)
            print("Waiting \(delay)s for \(description)")
            usleep(useconds_t(delay * 1000000))
        }
    }
}
