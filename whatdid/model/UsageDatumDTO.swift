// whatdid?

import Foundation
import CoreData

struct UsageDatumDTO {
    let objectID: NSManagedObjectID
    
    let datumId: UUID
    let trackerId: UUID
    let action: String
    let timestamp: Date
    let sendSuccess: Date?
}

extension UsageDatumDTO {
    init?(from managed: UsageDatum) {
        guard let datumId = managed.datumId,
              let trackerId = managed.trackerId,
              let action = managed.action,
              let timestamp = managed.timestamp
        else {
            return nil
        }
        self.objectID = managed.objectID
        self.datumId = datumId
        self.trackerId = trackerId
        self.action = action
        self.timestamp = timestamp
        self.sendSuccess = managed.sendSuccess
    }
}
