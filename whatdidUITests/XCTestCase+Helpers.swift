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
    
    class func log(_ message: String) {
        group(message) {}
    }
    
    func log(_ message: String) {
        XCTestCase.log(message)
    }
    
    func wait(timeout: TimeInterval = 5, pollEvery delay: TimeInterval = 0.25, for description: String, until condition: () -> Bool) {
        XCTestCase.wait(timeout: timeout, pollEvery: delay, for: description, until: condition)
    }
    
    class func wait(timeout: TimeInterval = 5, pollEvery delay: TimeInterval = 0.25, for description: String, until condition: () -> Bool) {
        group("Waiting for \(description)") {
            let tryUntil = Date().addingTimeInterval(timeout)
            while true {
                if condition() {
                    log("Success")
                    return
                }
                if Date() > tryUntil {
                    XCTFail("Timed out")
                }
                log("Waiting \(delay)s...")
            }
        }
    }
}
