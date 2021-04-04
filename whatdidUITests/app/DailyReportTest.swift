// whatdidUITests?

import XCTest
@testable import whatdid

class DailyReportTest: AppUITestBase {
    let secondsIn24Hrs = 86400
    
    /// Check that the daily report grows after it's contended with the PTN, such that projects are visible
    func testResizeAfterContentionWithPtn() {
        group("Initalize the data") {
            let entries = EntriesBuilder()
                .add(project: "project a", task: "task 1", notes: "first thing", minutes: 12)
                .add(project: "project a", task: "task 2", notes: "sidetrack", minutes: 13)
                .add(project: "project a", task: "task 1", notes: "back to first", minutes: 5)
                .add(project: "project b", task: "task 1", notes: "fizz", minutes: 5)
                .add(project: "project c", task: "task 2", notes: "fuzz", minutes: 10)
            let ptn = openPtn()
            let entriesSerialized = FlatEntry.serialize(entries.get(startingAtSecondsSince1970: secondsIn24Hrs))
            ptn.entriesHook.deleteText(andReplaceWith: entriesSerialized + "\r")
        }
        group("report opens while PTN is already open") {
            setTimeUtc(d: 1, h: 0, m: 0)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            waitForTransition(of: .ptn, toIsVisible: false)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
        }
        verifyVisibility(of: ["project a", "project b", "project c"], within: find(.dailyEnd))
    }
    
    func testSizeWhenOpeningUncontended() {
        group("fast-forward to just before daily report") {
            setTimeUtc(h: 15, m: 59)
            handleLongSessionPrompt(on: .ptn, .continueWithCurrentSession)
            let entries = EntriesBuilder()
                .add(project: "project a", task: "task 1", notes: "first thing", minutes: 12)
                .add(project: "project a", task: "task 2", notes: "sidetrack", minutes: 13)
                .add(project: "project a", task: "task 1", notes: "back to first", minutes: 5)
                .add(project: "project b", task: "task 1", notes: "fizz", minutes: 5)
                .add(project: "project c", task: "task 2", notes: "fuzz", minutes: 10)
            let entriesSerialized = FlatEntry.serialize(entries.get(startingAtSecondsSince1970: secondsIn24Hrs))
            openPtn().entriesHook.deleteText(andReplaceWith: entriesSerialized + "\r")
            clickStatusMenu() // dismiss the PTNc
            checkForAndDismiss(window: .morningGoals) // since we crossed the 9-hour mark
        }
        group("wait for daily report") {
            setTimeUtc(h: 16)
        }
        verifyVisibility(of: ["project a", "project b", "project c"], within: find(.dailyEnd))
    }
    
    func testTaskExpansion() {
        group("Initalize the data") {
            let entries = EntriesBuilder()
                .add(project: "project a", task: "task 1", notes: "first thing", minutes: 12)
                .add(project: "project a", task: "task 2", notes: "sidetrack", minutes: 13)
                .add(project: "project a", task: "task 1", notes: "back to first", minutes: 5)
                .add(project: "project b", task: "task 1", notes: "fizz", minutes: 5)
                .add(project: "project c", task: "task 2", notes: "fuzz", minutes: 10)
            let ptn = openPtn()
            let entriesTextField  = ptn.entriesHook
            entriesTextField.deleteText(andReplaceWith: FlatEntry.serialize(entries.get()))
            entriesTextField.typeKey(.enter)
        }
        group("bring up daily report") {
            clickStatusMenu()
            clickStatusMenu(with: .maskAlternate)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
        }
        group("Spot check on project a") {
            let dailyReport = find(.dailyEnd)
            let projectA = HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: "project a")
            let tasksForA = dailyReport.groups["Tasks for \"project a\""]
            let task1 = HierarchicalEntryLevel(ancestor: tasksForA, scope: "Task", label: "task 1")
            let task1Details = tasksForA.groups["Details for task 1"]
            group("Duration label and indicator") {
                XCTAssertEqual("30m", projectA.durationLabel.stringValue)
                if let indicatorBarValue = projectA.indicatorBar.value as? Double {
                    // 30 minutes out of 45 total = 0.6666...
                    XCTAssertGreaterThan(indicatorBarValue, 0.66)
                    XCTAssertLessThan(indicatorBarValue, 0.67)
                }
            }
            group("Check tasks for \"project a\"") {
                XCTAssertFalse(tasksForA.exists)
                projectA.clickDisclosure(until: tasksForA, .isVisible)
            }
            for task in ["task 1", "task 2"] {
                group("Check \(task)'s visibility") {
                    for (description, e) in HierarchicalEntryLevel(ancestor: tasksForA, scope: "Task", label: task).allElements {
                        e.hover()
                        XCTAssertTrue(e.isVisible, "\(task) \(description)")
                    }
                }
            }
            group("Spot check on task 1") {
                group("Duration label and indicator") {
                    XCTAssertEqual("17m", task1.durationLabel.stringValue)
                    if let indicatorBarValue = task1.indicatorBar.value as? Double {
                        // 17 minutes out of 45 total = 0.0.3777...
                        XCTAssertGreaterThan(indicatorBarValue, 0.37)
                        XCTAssertLessThan(indicatorBarValue, 0.38)
                    }
                }
                group("Details") {
                    XCTAssertFalse(task1Details.exists)
                    task1.clickDisclosure(until: task1Details, .isVisible)
                    XCTAssertEqual(
                        [
                            "1:15am - 1:27am (12m):",
                            "first thing",
                            "1:40am - 1:45am (5m):",
                            "back to first",
                        ],
                        task1Details.descendants(matching: .staticText).allElementsBoundByIndex.map({$0.stringValue}))
                }
            }
            group("Task 1 stays expanded if project a folds") {
                projectA.clickDisclosure(until: task1Details, .doesNotExist)
                log("Sleeping for a bit to let things stabilize")
                sleep(2) // Clicking too quickly in a row can break this test
                projectA.clickDisclosure(until: task1Details, .isVisible)
            }
        }
    }
    
    /// Create lots of projects, such that we need to scroll to see them all
    func testDailyReportScrollBar() {
        let ptn = openPtn()
        group("Initalize the data") {
            let manyEntries = EntriesBuilder()
            for i in 1...25 {
                manyEntries.add(project: "project \(i)", task: "only task", notes: "", minutes: Double(i))
            }
            ptn.entriesHook.deleteText(andReplaceWith: FlatEntry.serialize(manyEntries.get(startingAtSecondsSince1970: secondsIn24Hrs)))
            ptn.entriesHook.typeKey(.enter)
        }
        group("bring up daily report") {
            clickStatusMenu()
            clickStatusMenu(with: .maskAlternate)
            waitForTransition(of: .dailyEnd, toIsVisible: true)
        }
        let dailyReport = find(.dailyEnd)
        let project1Header = HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: "project 1").headerLabel
        let project25Header = HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: "project 25").headerLabel
        // each project N has 2*N minutes, so project 25 will be at the top
        group("project 25 is visible, project 1 is not") {
            XCTAssertTrue(project25Header.isVisible)
            XCTAssertFalse(project1Header.isVisible)
        }
        group("scroll to project 1") {
            project1Header.hover()
            XCTAssertFalse(project25Header.isVisible)
            XCTAssertTrue(project1Header.isVisible)
        }
    }

    class EntriesBuilder {
        private var _entries = [(p: String, t: String, n: String, duration: TimeInterval)]()
        
        @discardableResult func add(project: String, task: String, notes: String, minutes: Double) -> EntriesBuilder {
            _entries.append((p: project, t: task, n: notes, duration: minutes * 60.0))
            return self
        }
        
        func get(startingAtSecondsSince1970 start: Int = 0) -> [FlatEntry] {
            let totalInterval = _entries.map({$0.duration}).reduce(0, +)
            var startTime = Date(timeIntervalSince1970: Double(start) - totalInterval)
            var flatEntries = [FlatEntry]()
            for e in _entries {
                let from = startTime
                let to = startTime.addingTimeInterval(e.duration)
                flatEntries.append(FlatEntry(from: from, to: to, project: e.p, task: e.t, notes: e.n))
                startTime = to
            }
            return flatEntries
        }
    }
    
    func verifyVisibility(of projects: [String], within dailyReport: XCUIElement) {
        group("Verify projects are visible") {
            for project in projects {
                group(project) {
                    for (description, e) in HierarchicalEntryLevel(ancestor: dailyReport, scope: "Project", label: project).allElements {
                        XCTAssertTrue(e.isVisible, "\"\(project)\" \(description) are visible")
                    }
                }
            }
        }
    }
}
