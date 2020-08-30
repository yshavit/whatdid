// whatdidUITests?

import XCTest

extension XCTestCase {
    class func group<R>(_ name: String, _ block: () -> R) -> R {
        return XCTContext.runActivity(named: name, block: {_ in return block()})
    }
    
    func group<R>(_ name: String, _ block: () -> R) -> R {
        return XCTestCase.group(name, block)
    }
    
    func waitForCondition(timeout: TimeInterval = 1, delay: TimeInterval = 0.25, _ condition: () -> Bool) {
        let timeoutAt = Date().addingTimeInterval(timeout)
        while true {
            if condition() {
                return
            }
            XCTAssertLessThan(Date(), timeoutAt)
            print("delaying by \(useconds_t(delay * 1000000))")
            usleep(useconds_t(delay * 1000000))
        }
    }
    
    var activeAppBundleId: String? {
        // Without this, NSWorkspace.shared.frontmostApplication doesn't update. ::shrug::
        for app in NSWorkspace.shared.runningApplications {
            if app.isActive {
                break
            }
        }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
