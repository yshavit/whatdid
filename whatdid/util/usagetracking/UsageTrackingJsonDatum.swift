//
//  UsageTrackingJsonDatum.swift
//  whatdid
//
//  Created by Yuval Shavit on 10/9/23.
//  Copyright © 2023 Yuval Shavit. All rights reserved.
//

struct UsageTrackingJsonDatum: Codable {
    let datumId: String
    let trackerId: String
    let action: String
    let epochMillis: Int64
    
    enum CodingKeys: String, CodingKey {
        case datumId = "datum_id"
        case trackerId = "tracker_id"
        case action
        case epochMillis = "epoch_millis"
    }
}

extension UsageTrackingJsonDatum {
    init(from dto: UsageDatumDTO) {
        self.datumId = dto.datumId.uuidString
        self.trackerId = dto.trackerId.uuidString
        self.action = dto.action
        self.epochMillis = Int64(dto.timestamp.timeIntervalSince1970) * 1000
    }
}
