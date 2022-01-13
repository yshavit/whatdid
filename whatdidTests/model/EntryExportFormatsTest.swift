// whatdidTests?

import XCTest
@testable import whatdid

class EntryExportFormatsTest: XCTestCase {
    
    private let entries = [
        FlatEntry(from: hour(0), to: hour(1), project: "main project", task: "first task", notes: "my notes"),
        FlatEntry(from: hour(2), to: hour(3), project: "main project", task: "first task", notes: nil),
        FlatEntry(from: hour(4), to: hour(5), project: "main project", task: "second task", notes: ""),
        FlatEntry(from: hour(6), to: hour(7), project: "second project", task: "third task", notes: "last notes"),
    ].shuffled() // order shouldn't matter

    func testCsv() throws {
        let result = try entriesToString(using: CsvEntryExportFormat())
        let expected = lines(
            "start_time,end_time,project,task,notes",
            q("'1970-01-01T00:00:00Z','1970-01-01T01:00:00Z','main project','first task','my notes'"),
            q("'1970-01-01T02:00:00Z','1970-01-01T03:00:00Z','main project','first task',"),
            q("'1970-01-01T04:00:00Z','1970-01-01T05:00:00Z','main project','second task',"),
            q("'1970-01-01T06:00:00Z','1970-01-01T07:00:00Z','second project','third task','last notes'")
        )
        XCTAssertEqual(expected, result)
    }
    
    func testJson() throws {
        let result = try entriesToString(using: JsonEntryExportFormat())
        typealias Project = String
        typealias Task = String
        typealias Entry = [String : String]
        typealias ExportStructure = [Project : [Task : [Entry]]]
        let expected = [
            "main project": [
                "first task": [
                    ["from":"1970-01-01T00:00:00Z","to":"1970-01-01T01:00:00Z","notes":"my notes"],
                    ["from":"1970-01-01T02:00:00Z","to":"1970-01-01T03:00:00Z","notes":""]
                ],
                "second task": [
                    ["from":"1970-01-01T04:00:00Z","to":"1970-01-01T05:00:00Z","notes":""]
                ]
            ],
            "second project": [
                "third task": [
                    ["from":"1970-01-01T06:00:00Z","to":"1970-01-01T07:00:00Z","notes":"last notes"]
                ]
            ]
        ]
        let json = JSONDecoder()
        let resultAsJson = try json.decode(ExportStructure.self, from: result.data(using: .utf8)!)
        XCTAssertEqual(expected, resultAsJson)
    }
    
    func testTree() throws {
        let result = try entriesToString(using: TextTreeEntryExportFormat())
        let expected = lines(
            "Total time: 4h 0m",
            "    75.0% (3h 0m): main project",
            "        50.0% (2h 0m): first task",
            "            25.0% (1h 0m): my notes",
            "            25.0% (1h 0m): (no notes entered)",
            "        25.0% (1h 0m): second task",
            "            25.0% (1h 0m): (no notes entered)",
            "    25.0% (1h 0m): second project",
            "        25.0% (1h 0m): third task",
            "            25.0% (1h 0m): last notes")
        XCTAssertEqual(expected, result)
    }
    
    private func entriesToString(using format: EntryExportFormat) throws -> String {
        let buffer = OutputStream(toMemory: ())
        buffer.open()
        try format.write(entries: entries, to: buffer)
        buffer.close()
        let data = buffer.property(forKey: .dataWrittenToMemoryStreamKey) as! Data
        return String(data: data, encoding: .utf8)!
    }
}

private func hour(_ hour: Int) -> Date {
    return Date(timeIntervalSince1970: TimeInterval(hour) * 60.0 * 60.0)
}

/// Joins all of the given strings via a newline char, and adds one more newline at the end.
private func lines(_ lines: String...) -> String {
    return lines.joined(separator: "\n") + "\n"
}

/// Convert all single-quotes (`'`) to double quotes (`"`).
///
/// This just makes it nicer to add double quotes without having to escape them in the source.
func q(_ string: String) -> String {
    return string.replacingOccurrences(of: "'", with: "\"")
}
