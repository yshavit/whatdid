// whatdid?

import Cocoa

extension NSRange {
    static func arrayFrom(ints unsorted: [Int]) -> [NSRange] {
        if unsorted.isEmpty {
            return []
        }
        var results = [NSRange]()
        
        let sortedInts = unsorted.sorted()
        var sequenceLowValue = sortedInts[0]
        var sequenceHighValue = sequenceLowValue
        for value in sortedInts[1...] {
            if value > sequenceHighValue + 1 {
                results.append(from(low: sequenceLowValue, toHigh: sequenceHighValue))
                sequenceLowValue = value
                sequenceHighValue = value
            } else {
                sequenceHighValue = value
            }
        }
        results.append(from(low: sequenceLowValue, toHigh: sequenceHighValue))
        return results
    }
    
    private static func from(low: Int, toHigh high: Int) -> NSRange {
        NSRange(location: low, length: high - low + 1) // +1 because e.g. [3, 3] has length 1
    }
}
