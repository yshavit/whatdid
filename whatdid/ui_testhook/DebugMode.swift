// whatdid?
#if UI_TEST

import Foundation

enum DebugMode : String {
    case buttonWithClosure
    case autoCompleter
    
    static let DEBUG_MODE_ARG_PREFIX = "debug:"
    
    init?(fromStringIfWithPrefix string: String) {
        var parsed : DebugMode?
        if string.hasPrefix(DebugMode.DEBUG_MODE_ARG_PREFIX) {
            let prefixIndex = DebugMode.DEBUG_MODE_ARG_PREFIX.endIndex
            if let startOfModeInPrefixedString = prefixIndex.samePosition(in: string) {
                let modeStr = String(string.suffix(from: startOfModeInPrefixedString))
                parsed = DebugMode(rawValue: modeStr)
            }
        }
        if let parsedAs = parsed {
            self = parsedAs
        } else {
            return nil
        }
    }
    
    func toLaunchArgument() -> String {
        return DebugMode.DEBUG_MODE_ARG_PREFIX + rawValue
    }
}

#endif
