// whatdid?

import Cocoa

extension NSButton {
    #if UI_TEST
    /// Cycles the button's styles, so that you can see which you like best
    func cycleStylesForUIBikeshedding() {
        let allStyles: [(String, NSButton.BezelStyle)] = [
            ("circular", .circular),
            ("disclosure", .disclosure),
            ("helpButton", .helpButton),
            ("inline", .inline),
            ("recessed", .recessed),
            ("regularSquare", .regularSquare),
            ("roundRect", .roundRect),
            ("rounded", .rounded),
            ("roundedDisclosure", .roundedDisclosure),
            ("shadowlessSquare", .shadowlessSquare),
            ("smallSquare", .smallSquare),
            ("texturedRounded", .texturedRounded),
            ("texturedSquare", .texturedSquare),
        ]
        var i = 0
        func cycleOnce() {
            let style = allStyles[i]
            i = (i + 1) % allStyles.count
            NSLog("styling as: \(style.0)")
            bezelStyle = style.1
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(1000), execute: cycleOnce)
        }
        cycleOnce()
    }
    #endif
}
