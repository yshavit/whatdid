// whatdid?
import Cocoa

struct FlatEntry: CustomStringConvertible, Codable, Equatable, Hashable {
    
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
        String(
            format: "project(%@), task(%@), notes(%@) from %@ to %@",
            project,
            task,
            notes ?? "",
            from.debugDescription,
            to.debugDescription
        )
    }

    func replacing(project: String, task: String, notes: String?) -> FlatEntry {
        let maybeNotes = notes.flatMap({$0.isEmpty ? nil : $0})
        return FlatEntry(from: from, to: to, project: project, task: task, notes: maybeNotes)
    }
}

struct RewriteableFlatEntry {
    let entry: FlatEntry
    let objectId: NSManagedObjectID

    func map(modify: (FlatEntry) -> FlatEntry) -> RewrittenFlatEntry {
        RewrittenFlatEntry(original: self, newValue: modify(entry))
    }
}

struct RewrittenFlatEntry {
    let original: RewriteableFlatEntry
    let newValue: FlatEntry
}

extension Array where Element == RewriteableFlatEntry {
    var withoutObjectIds: [FlatEntry] {
        map({$0.entry})
    }
}