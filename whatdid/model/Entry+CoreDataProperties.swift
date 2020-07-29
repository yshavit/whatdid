// wtfdid?

import Foundation
import CoreData


extension Entry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entry> {
        return NSFetchRequest<Entry>(entityName: "Entry")
    }

    @NSManaged public var notes: String?
    @NSManaged public var timeApproximatelyStarted: Date
    @NSManaged public var timeEntered: Date
    @NSManaged public var task: Task

}
