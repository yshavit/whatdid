// whatdid?

#if UI_TEST
import Foundation

class SampleData {
    var onFail: ((String) -> Void)
    var now: Date
    var entryTransform: ((FlatEntry) -> FlatEntry)? = nil
    
    init(relativeTo date: Date, onFail: @escaping (String) -> Void) {
        self.now = date
        self.onFail = onFail
    }
    
    func entries() -> [FlatEntry] {
        let cal = Calendar.current
        let lastMidnight = cal.date(bySettingHour: 00, minute: 00, second: 00, of: now)!
        var lastEntryEnd: Date? = nil
        
        var nodes = [FlatEntry]()
        for line in readEntriesFile().split(separator: "\n") {
            /// The format is a backslash delimited line::
            /// ```
            /// | hh:mm | project | task | notes |`
            /// ```
            /// Note that the `hh:mm` is _not_ tab-delimited; that uses a colon, so that it reads nicely.
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }
            let segments = trimmed.split(separator: "|").map({$0.trimmingCharacters(in: .whitespaces)})
            let hhmm = segments[0].split(separator: ":")
            let project = segments[1]
            let task = segments.maybe(2) ?? ""
            let notes = segments.maybe(3) ?? ""
            
            if hhmm.count != 2 {
                self.onFail("expected 2 segments, found \(hhmm.count): \(line)")
            }
            
            let hours = Int(hhmm[0])!
            let mins = Int(hhmm[1])!
            
            let endDate = cal.date(bySettingHour: hours, minute: mins, second: 0, of: lastMidnight)!
            let startDate = lastEntryEnd ?? endDate.addingTimeInterval(-300)
            nodes.append(
                FlatEntry(
                    from: startDate,
                    to: endDate,
                    project: String(project),
                    task: String(task),
                    notes: String(notes)))
            lastEntryEnd = endDate
        }
        if let entryTransform = entryTransform {
            nodes = nodes.map(entryTransform)
        }
        return nodes
    }
    
    private func readEntriesFile() -> String {
        let bundle = Bundle(for: Swift.type(of: self))
        guard let path = bundle.path(forResource: "screenshot-entries", ofType: "txt") else {
            return failAndReturn(with: "couldn't find resource")
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            return failAndReturn(with: "no data in resource")
        }
        guard let string = String(data: data, encoding: .utf8) else {
            return failAndReturn(with: "invalid data in resource")
        }
        return string
    }
    
    private func failAndReturn<T>(with message: String) -> T {
        let maybe: T? = nil
        onFail(message)
        return maybe!
    }
}

private extension Array {
    func maybe(_ index: Int) -> Element? {
        guard index >= 0 && index < count else {
            return nil
        }
        return self[index]
    }
}

#endif
