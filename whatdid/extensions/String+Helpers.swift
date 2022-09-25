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
    
    /// Drops the suffix from this string, if it is present. Returns the resulting string if the suffix was there, or `nil` if it wasn't.
    func dropping(suffix: String) -> String? {
        if hasSuffix(suffix) {
            return String(dropLast(suffix.count))
        } else {
            return nil
        }
    }
}
