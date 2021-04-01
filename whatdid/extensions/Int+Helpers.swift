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
    
    func pluralize(_ singular: String, _ plural: String, showValue: Bool = true) -> String {
        let s = (self == 1) ? singular : plural
        return showValue ? "\(self) \(s)" : s
    }
}
