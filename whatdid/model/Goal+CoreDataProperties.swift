//
//  Goal+CoreDataProperties.swift
//  whatdid
//
//  Created by Yuval Shavit on 3/24/21.
//  Copyright © 2021 Yuval Shavit. All rights reserved.
//
//

import Foundation
import CoreData


extension Goal {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Goal> {
        return NSFetchRequest<Goal>(entityName: "Goal")
    }

    @NSManaged public var goal: String
    @NSManaged public var created: Date!
    @NSManaged public var completed: Date?
    @NSManaged public var during: Session?
    @NSManaged public var orderWithinSession: NSNumber?

}
