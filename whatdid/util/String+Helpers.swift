// whatdid?

import Cocoa

extension String {
    func fullNsRange() -> NSRange {
        NSRange(location: 0, length: count)
    }
}
