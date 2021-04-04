// whatdidUITests?

import XCTest

extension XCTestCase {
    class func group<R>(_ name: String, _ block: () -> R) -> R {
        return XCTContext.runActivity(named: name, block: {_ in return block()})
    }
    
    
    class func clickEvent(_ mouseButton: CGMouseButton, _ mouseType: CGEventType, at position: CGPoint, with flags: CGEventFlags) {
        let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
        let downEvent = CGEvent(mouseEventSource: src, mouseType: mouseType, mouseCursorPosition: position, mouseButton: mouseButton)
        downEvent?.flags = flags
        downEvent?.post(tap: CGEventTapLocation.cghidEventTap)
        sleepMillis(50)
    }
    
    func clickEvent(_ mouseButton: CGMouseButton, _ mouseType: CGEventType, at position: CGPoint, with flags: CGEventFlags) {
        XCTestCase.clickEvent(mouseButton, mouseType, at: position, with: flags)
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
