// whatdidUITests?

import XCTest

extension XCTestCase {
    func group<R>(_ name: String, _ block: () -> R) -> R{
        return XCTContext.runActivity(named: name, block: {_ in return block()})
    }
}
