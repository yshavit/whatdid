// whatdid?

import Cocoa

extension Date {
    
    func timestamp(at timeZone: TimeZone) -> String {
        let options = ISO8601DateFormatter.Options([.withInternetDateTime, .withFractionalSeconds])
        return ISO8601DateFormatter.string(from: self, timeZone: timeZone, formatOptions: options)
    }
    
    var utcTimestamp: String {
        get {
            timestamp(at: TimeZone(identifier: "UTC")!)
        }
    }
}
