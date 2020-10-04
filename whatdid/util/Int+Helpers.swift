// whatdid?

import Cocoa

extension Int {
    func clipped(to range: ClosedRange<Int>) -> Int {
        if self < range.lowerBound {
            return range.lowerBound
        } else if self > range.upperBound {
            return range.upperBound
        }
        return self
    }
}
