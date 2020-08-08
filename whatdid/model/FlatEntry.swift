// whatdid?
import Cocoa

struct FlatEntry {
    
    let from : Date
    let to : Date
    let project : String
    let task : String
    let notes : String?
    
    var duration: TimeInterval {
        get {
            return (to.timeIntervalSince1970 - from.timeIntervalSince1970)
        }
    }
}
