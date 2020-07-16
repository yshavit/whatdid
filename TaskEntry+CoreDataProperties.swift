//
//  TaskEntry+CoreDataProperties.swift
//  wtfdid
//
//  Created by Yuval Shavit on 7/15/20.
//  Copyright © 2020 Yuval Shavit. All rights reserved.
//
//

import Foundation
import CoreData


extension TaskEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntry> {
        return NSFetchRequest<TaskEntry>(entityName: "TaskEntry")
    }

    @NSManaged public var task: String?
    @NSManaged public var notes: String?
    @NSManaged public var enteredAt: Date?
    @NSManaged public var partOf: Project?

}
