// whatdid?

import Cocoa

extension NSAppearance {
    /// Fetches things like the latest NSColor values.
    ///
    /// See: https://stackoverflow.com/a/63859580/1076640
    static func withEffectiveAppearance(_ block: () -> Void) {
        let previousAppearance = NSAppearance.current
        defer {
            NSAppearance.current = previousAppearance
        }
        NSAppearance.current = NSApp.effectiveAppearance
        block()
    }
}
