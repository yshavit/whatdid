//
//  Project+CoreDataProperties.swift
//  wtfdid
//
//  Created by Yuval Shavit on 7/15/20.
//  Copyright © 2020 Yuval Shavit. All rights reserved.
//
//

import Foundation
import CoreData


extension Project {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Project> {
        return NSFetchRequest<Project>(entityName: "Project")
    }

    @NSManaged public var project: String
    @NSManaged public var taskEntries: NSSet

}

// MARK: Generated accessors for taskEntries
extension Project {

    @objc(addTaskEntriesObject:)
    @NSManaged public func addToTaskEntries(_ value: TaskEntry)

    @objc(removeTaskEntriesObject:)
    @NSManaged public func removeFromTaskEntries(_ value: TaskEntry)

    @objc(addTaskEntries:)
    @NSManaged public func addToTaskEntries(_ values: NSSet)

    @objc(removeTaskEntries:)
    @NSManaged public func removeFromTaskEntries(_ values: NSSet)

}
