// whatdid?
import Cocoa

struct FlatEntry: CustomStringConvertible, Codable, Equatable {
    
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
    
    var description: String {
        return String(
            format: "project(%@), task(%@), notes(%@) from %@ to %@",
            project,
            task,
            notes ?? "",
            from.debugDescription,
            to.debugDescription
        )
    }
}
