//
//  Session+CoreDataProperties.swift
//  whatdid
//
//  Created by Yuval Shavit on 3/24/21.
//  Copyright © 2021 Yuval Shavit. All rights reserved.
//
//

import Foundation
import CoreData


extension Session {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Session> {
        return NSFetchRequest<Session>(entityName: "Session")
    }

    @NSManaged public var startTime: Date?
    @NSManaged public var goals: Set<Goal>

}

// MARK: Generated accessors for goals
extension Session {

    @objc(addGoalsObject:)
    @NSManaged public func addToGoals(_ value: Goal)

    @objc(removeGoalsObject:)
    @NSManaged public func removeFromGoals(_ value: Goal)

    @objc(addGoals:)
    @NSManaged public func addToGoals(_ values: NSSet)

    @objc(removeGoals:)
    @NSManaged public func removeFromGoals(_ values: NSSet)

}
