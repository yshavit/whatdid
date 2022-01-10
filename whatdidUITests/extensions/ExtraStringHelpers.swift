// whatdidUITests?

import Foundation

extension String {

    var rot13: String {
        get {
            let trChars = self.map {c -> Character in
                if let tr = rot13Char(for: .upper, map: c) {
                    return tr
                } else if let tr = rot13Char(for: .lower, map: c) {
                    return tr
                } else {
                    return c
                }
            }
            return String(trChars)
        }
    }
}

private enum Capitalization: Character {
    case upper = "A"
    case lower = "a"
}

private func rot13Char(for capitalization: Capitalization, map target: Character) -> Character? {
    guard let fromUtf8 = capitalization.rawValue.asciiValue, let targetUtf8 = target.asciiValue else {
        return nil
    }
    let toUtf8 = fromUtf8 + 26
    guard targetUtf8 >= fromUtf8 && targetUtf8 < toUtf8 else {
        return nil
    }
    let char0Indexed = targetUtf8 - fromUtf8
    let mapped = (char0Indexed + 13) % 26
    return Character(UnicodeScalar(mapped + fromUtf8))
}
