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
}
