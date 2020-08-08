// whatdidUITests?

import XCTest

class FlatEntry_SerdeTests: XCTestCase {

    /// There and back
    func testSerde() {
        let toDate = Date()
        let fromDate = toDate.addingTimeInterval( -12345)
        let orig = FlatEntry(from: fromDate, to: toDate, project: "p1", task: "t1", notes: "my notes")
        
        let serialized = orig.serialize()
        XCTAssertNotNil(serialized)
        
        let fromJson = FlatEntry(fromSerialized: serialized!)
        XCTAssertEqual(fromJson, orig)
    }

    /// Just so we're sure it's not pretty-printed; we want a nice compact format
    func testSerdeHasNoWhitespace() {
        let toDate = Date()
        let fromDate = toDate.addingTimeInterval( -12345)
        let orig = FlatEntry(from: fromDate, to: toDate, project: "p1", task: "t1", notes: "notes")
        
        let json = orig.serialize()
        XCTAssertNotNil(json)
        
        let whiteSpace = json?.firstIndex(where: {$0.isWhitespace})
        XCTAssertNil(whiteSpace)
    }

}
