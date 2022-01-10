// whatdidUITests?

import XCTest

extension XCTestCase {
    class func group<R>(_ name: String, _ block: () -> R) -> R {
        return XCTContext.runActivity(named: name, block: {_ in return block()})
    }
    
    class func pauseToLetStabilize() {
        sleepMillis(150)
    }
    
    func pauseToLetStabilize() {
        XCTestCase.sleepMillis(150)
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
    
    func wait<T: Equatable>(until block: () -> T, equals expected: T) {
        wait(for: "element to equal expected", until: {block() == expected})
    }
    
    func wait(for description: String, timeout: TimeInterval = 30, until condition: () -> Bool) {
        XCTestCase.wait(for: description, until: condition)
    }
    
    func XCTAssertClose(_ first: CGFloat, _ second: CGFloat, within allowedSpread: CGFloat) {
        let delta = abs(first - second)
        XCTAssertLessThanOrEqual(delta, allowedSpread, "\(first) was not within \(allowedSpread) of \(second)")
    }
    
    class func wait(for description: String, timeout: TimeInterval = 30, until condition: () -> Bool) {
        let delay: TimeInterval = 1
        group("Waiting for \(description)") {
            let tryUntil = Date().addingTimeInterval(timeout)
            for i in 1... {
                let success = group("Attempt #\(i)") {() -> Bool in
                    if condition() {
                        log("Success")
                        return true
                    }
                    if Date() > tryUntil {
                        XCTFail("Timed out after \(timeout)s")
                    }
                    sleepMillis(Int(delay * 1000))
                    return false
                }
                if success {
                    return
                }
            }
        }
    }
}
