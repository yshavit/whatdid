// whatdid?

import Cocoa

extension String {
    func fullNsRange() -> NSRange {
        NSRange(location: 0, length: count)
    }
    
    func replacingBracketedPlaceholders(with replacements: [String: String]) -> String {
        var result = self
        for (key, value) in replacements {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
    
    var hashToColor: NSColor {
        let hashUInt = UInt32(truncatingIfNeeded: hashValue)
        let rand = SimpleRandom(seed: hashUInt)
        return NSColor(
            red: CGFloat(rand.nextUnitFloat()),
            green: CGFloat(rand.nextUnitFloat()),
            blue: CGFloat(rand.nextUnitFloat()),
            alpha: 1.0)
    }
}
