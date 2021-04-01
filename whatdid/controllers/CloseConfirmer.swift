// whatdid?

import Cocoa

protocol CloseConfirmer {
    func requestClose(on: NSWindow) -> Bool
}
