// whatdid?

import Foundation

class SubsequenceMatcher {
    private init() {
        // nothing
    }
    
    static func matches<T: StringProtocol>(lookFor needle: T, inString haystack: T) -> [NSRange] {
        var needleChars = needle.lowercased().unicodeScalars.makeIterator()
        let haystackUnicodeScalars = haystack.lowercased().unicodeScalars
        var remainingHaystack = Substring.UnicodeScalarView(haystackUnicodeScalars)
        var foundIndices = [Int]()
        while let lookForChar = needleChars.next() {
            if let foundCharAt = remainingHaystack.firstIndex(of: lookForChar) {
                let offset = haystackUnicodeScalars.distance(from: haystackUnicodeScalars.startIndex, to: foundCharAt)
                foundIndices.append(offset)
                remainingHaystack = remainingHaystack.suffix(from: remainingHaystack.index(after: foundCharAt))
            } else {
                return []
            }
        }
        return NSRange.arrayFrom(ints: foundIndices)
    }

    static func hasMatches<T: StringProtocol>(lookFor needle: T, inString haystack: T) -> Bool {
        !matches(lookFor: needle, inString: haystack).isEmpty
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
                        wdlog(.error, "bad range: %{public}@ in string of length %d", range.description, string.count)
                        return nil
                    }
                }
                self.string = string
                self.matchedRanges = matchedRanges
            }
        }
    }
}
