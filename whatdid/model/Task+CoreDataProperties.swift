// whatdid?

import Foundation
import CoreData


extension Task {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Task> {
        return NSFetchRequest<Task>(entityName: "Task")
    }

    @NSManaged public var lastUsed: Date
    @NSManaged public var task: String
    @NSManaged public var entries: Set<Entry>
    @NSManaged public var project: Project
    
    @NSManaged private var projectName: String?
    
    public override func awakeFromFetch() {
        projectName = project.project
        super.awakeFromFetch()
    }
    
    public override func validateForUpdate() throws {
        setProjectName()
        try super.validateForUpdate()
    }
    
    public override func validateForDelete() throws {
        setProjectName()
        try super.validateForDelete()
    }
    
    public override func validateForInsert() throws {
        setProjectName()
        try super.validateForInsert()
    }
    
    private func setProjectName() {
        if projectName == nil {
            projectName = project.project
        }
    }
}

// MARK: Generated accessors for entries
extension Task {

    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: Entry)

    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: Entry)

    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)

    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)

}
