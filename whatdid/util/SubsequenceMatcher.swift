// whatdid?

import Foundation

class SubsequenceMatcher {
    private init() {
        // nothing
    }
    
    static func match(lookFor needle: String, inStrings haystacks: [String]) -> [Match] {
        return haystacks.compactMap { Match(string: $0, matchedRanges: matches(lookFor: needle, inString: $0)) }
    }
    
    static func matches(lookFor needle: String, inString haystack: String) -> [NSRange] {
        var needleChars = needle.unicodeScalars.makeIterator()
        let haystackUnicodeScalars = haystack.lowercased().unicodeScalars
        var remainingHaystack = Substring.UnicodeScalarView(haystackUnicodeScalars)
        var foundIndices = [Int]()
        while let lookForChar = needleChars.next() {
            if let foundCharAt = remainingHaystack.firstIndex(of: lookForChar) {
                let offset = haystack.distance(from: haystackUnicodeScalars.startIndex, to: foundCharAt)
                foundIndices.append(offset)
                remainingHaystack = remainingHaystack.suffix(from: remainingHaystack.index(after: foundCharAt))
            } else {
                return []
            }
        }
        return NSRange.arrayFrom(ints: foundIndices)
    }
    
    struct Match: Equatable {
        let string: String
        let matchedRanges: [NSRange]
        
        init?(string: String, matchedRanges: [NSRange]) {
            if matchedRanges.isEmpty {
                return nil
            } else {
                for range in matchedRanges {
                    if (range.location < 0) || (range.location + range.length > string.count) {
                        NSLog("bad range: \(range) in \(string)")
                        return nil
                    }
                }
                self.string = string
                self.matchedRanges = matchedRanges
            }
        }
    }
}
