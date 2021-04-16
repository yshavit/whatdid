// whatdid?

import os

extension OSLogType {
    /// Equivalent to `.default`.
    ///
    /// This is a clearer label for that `.default`'s description:
    /// "Use this level to capture information about things that might result in a failure."
    static let warn = OSLogType.default
    
    var asString: String {
        get {
            switch self {
            case .debug:   return "DEBUG"
            case .default: return "WARN "
            case .error:   return "ERROR"
            case .fault:   return "FAULT"
            case .info:    return "INFO "
            default:       return "(log@\(rawValue))"
            }
        }
    }
}
