// whatdidTests?

import XCTest
@testable import whatdid

class PrefsViewControllerTest: XCTestCase {

    func testExportFormat() {
        /// Saturday, June 4, 2022 9:23:40 PM GMT-04:00 DST
        let date = Date(timeIntervalSince1970: 1654392220)
        let scheduler = DummyScheduler(now: date)
        let actual = PrefsViewController.exportFileName(JsonEntryExportFormat(), scheduler)
        XCTAssertEqual("whatdid-export-2022-06-04T212340-0400.json", actual)
    }
    
    fileprivate struct DummyScheduler: Scheduler {
        func schedule(_ description: String, at: Date, _ block: @escaping () -> Void) -> ScheduledTask {
            fatalError("schedule() not implemented")
        }
        
        let now: Date
        let timeZone = TimeZone(identifier: "US/Eastern")!
        let calendar = Calendar(identifier: .gregorian)
    }
}



