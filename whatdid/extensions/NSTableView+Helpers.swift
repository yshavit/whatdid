// whatdid?

import Cocoa

extension NSTableView {
    var visibleRowIndexes: IndexSet {
        var result = IndexSet(integersIn: 0..<numberOfRows)
        for i in hiddenRowIndexes {
            result.remove(i)
        }
        return result
    }
}
