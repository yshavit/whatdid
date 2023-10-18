// whatdidTests?

import XCTest
@testable import Whatdid

class SortedMapTest: XCTestCase {
    
    typealias E = SortedMap<Float, String>.Entry
    private let e = SortedMap<Float, String>.Entry.init
    
    func testEmptySet() {
        let s = SortedMap<Float, String>()
        XCTAssertEqual(nil, s.find(highestEntryLessThanOrEqualTo: -1.0))
    }
    
    func testNeedleLessThanLowest() {
        var s = SortedMap<Float, String>()
        s.add(kvPairs: [(0, "a"), (1.1, "b"), (2.2, "c"), (3.3, "d"), (4.4, "e")])
        XCTAssertEqual(nil, s.find(highestEntryLessThanOrEqualTo: -1.0))
    }
    
    func testEmptyAdd() {
        var s = SortedMap<Float, String>()
        XCTAssertTrue(s.entries.isEmpty)
        s.add(entries: [])
        XCTAssertTrue(s.entries.isEmpty)
    }

    func testSimpleOddLength() {
        var s = SortedMap<Float, String>()
        s.add(kvPairs: [(0, "a"), (1.1, "b"), (2.2, "c"), (3.3, "d"), (4.4, "e")])
        XCTAssertEqual([e(0, "a"), e(1.1, "b"), e(2.2, "c"), e(3.3, "d"), e(4.4, "e")], s.entries)

        XCTAssertEqual("a", s.find(highestEntryLessThanOrEqualTo: 0))
        XCTAssertEqual("a", s.find(highestEntryLessThanOrEqualTo: 1.0))

        XCTAssertEqual("b", s.find(highestEntryLessThanOrEqualTo: 1.1))
        XCTAssertEqual("b", s.find(highestEntryLessThanOrEqualTo: 1.2))

        XCTAssertEqual("c", s.find(highestEntryLessThanOrEqualTo: 2.2))
        XCTAssertEqual("c", s.find(highestEntryLessThanOrEqualTo: 2.3))

        XCTAssertEqual("d", s.find(highestEntryLessThanOrEqualTo: 3.3))
        XCTAssertEqual("d", s.find(highestEntryLessThanOrEqualTo: 3.4))

        XCTAssertEqual("e", s.find(highestEntryLessThanOrEqualTo: 4.4))
        XCTAssertEqual("e", s.find(highestEntryLessThanOrEqualTo: 4.5))
    }

    func testSimpleEvenLength() {
        var s = SortedMap<Float, String>()
        s.add(kvPairs: [(0, "a"), (1.1, "b"), (2.2, "c"), (3.3, "d")])
        XCTAssertEqual([e(0, "a"), e(1.1, "b"), e(2.2, "c"), e(3.3, "d")], s.entries)

        XCTAssertEqual("a", s.find(highestEntryLessThanOrEqualTo: 0))
        XCTAssertEqual("a", s.find(highestEntryLessThanOrEqualTo: 1.0))

        XCTAssertEqual("b", s.find(highestEntryLessThanOrEqualTo: 1.1))
        XCTAssertEqual("b", s.find(highestEntryLessThanOrEqualTo: 1.2))

        XCTAssertEqual("c", s.find(highestEntryLessThanOrEqualTo: 2.2))
        XCTAssertEqual("c", s.find(highestEntryLessThanOrEqualTo: 2.3))

        XCTAssertEqual("d", s.find(highestEntryLessThanOrEqualTo: 3.3))
        XCTAssertEqual("d", s.find(highestEntryLessThanOrEqualTo: 3.4))
    }

    func testInsertInOrder() {
        var s = SortedMap<Float, String>()
        s.add(kvPairs: [(0.0, "a"), (1.1, "b"), (2.2, "c")])
        XCTAssertEqual([0, 1.1, 2.2], s.entries.map({$0.key}))
    }

    func testInsertReverseOrder() {
        var s = SortedMap<Float, String>()
        s.add(kvPairs: [(2.2, "c"), (1.1, "b"), (0.0, "a"), ])
        XCTAssertEqual([0, 1.1, 2.2], s.entries.map({$0.key}))
    }

    func testInsertMixedOrder() {
        var s = SortedMap<Float, String>()
        s.add(kvPairs: [(1.1, "b"), (2.2, "c"), (0.0, "a"), ])
        XCTAssertEqual([0, 1.1, 2.2], s.entries.map({$0.key}))
    }

    func testInsertDuplicate() {
        var s = SortedMap<Float, String>()
        s.add(kvPairs: [(2.2, "c"), (1.1, "b"), (0.0, "a"), (1.1, "b"), (2.2, "c")])
        XCTAssertEqual([0, 1.1, 2.2], s.entries.map({$0.key}))
    }

    func testInsertOneAtATime() {
        var s = SortedMap<Float, String>()
        for i in [0, 1.1, 2.2] {
            s.add(entries: [e(Float(i), "v=\(i)")])
        }
        XCTAssertEqual([0, 1.1, 2.2], s.entries.map({$0.key}))
        XCTAssertEqual(["v=0.0", "v=1.1", "v=2.2"], s.entries.map({$0.value}))
    }

    func testRemoveAll() {
        var s = SortedMap<Float, String>()
        s.add(kvPairs: [(2.2, "c"), (1.1, "b"), (0.0, "a"), (1.1, "b"), (2.2, "c")])
        XCTAssertEqual([0, 1.1, 2.2], s.entries.map({$0.key}))
        s.removeAll()
        XCTAssertEqual([], s.entries)
    }
}
