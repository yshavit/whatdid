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
            let _ = openPtn()
            entriesHook = entries.get(startingAtSecondsSince1970: secondsIn24Hrs)
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
        group("set some values") {
            let entries = EntriesBuilder()
                .add(project: "project a", task: "task 1", notes: "first thing", minutes: 12)
                .add(project: "project a", task: "task 2", notes: "sidetrack", minutes: 13)
                .add(project: "project a", task: "task 1", notes: "back to first", minutes: 5)
                .add(project: "project b", task: "task 1", notes: "fizz", minutes: 5)
                .add(project: "project c", task: "task 2", notes: "fuzz", minutes: 10)
            entriesHook = entries.get(startingAtSecondsSince1970: secondsIn24Hrs)
        }
        group("fast-forward to just before daily report") {
            setTimeUtc(h: 15, m: 59)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
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
            entriesHook = entries.get()
        }
        group("bring up daily report") {
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
                XCTAssertFalse(tasksForA.isVisible)
                projectA.clickDisclosure(until: tasksForA, isVisible: true)
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
                    XCTAssertFalse(task1Details.isVisible)
                    task1.clickDisclosure(until: task1Details, isVisible: true)
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
                projectA.clickDisclosure(until: task1Details, isVisible: false)
                log("Sleeping for a bit to let things stabilize")
                sleep(2) // Clicking too quickly in a row can break this test
                projectA.clickDisclosure(until: task1Details, isVisible: true)
            }
        }
    }
    
    /// Create lots of projects, such that we need to scroll to see them all
    func testDailyReportScrollBar() {
        group("Initalize the data") {
            let manyEntries = EntriesBuilder()
            for i in 1...25 {
                manyEntries.add(project: "project \(i)", task: "only task", notes: "", minutes: Double(i))
            }
            entriesHook = manyEntries.get(startingAtSecondsSince1970: secondsIn24Hrs)
        }
        group("bring up daily report") {
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
    
    func testDailyReportResizing() {
        let longProjectName = "The quick brown fox jumped over the lazy dog because the dog was just so lazy. Poor dog."
        group("Set up events with long text") {
            let twelveHoursFromEpoch = Date(timeIntervalSince1970: 43200)
            entriesHook = [
                entry(
                    longProjectName,
                    "Some task",
                    "Some notes",
                    from: twelveHoursFromEpoch,
                    to: twelveHoursFromEpoch.addingTimeInterval(60)),
                entry(
                    "short project",
                    "short task",
                    "short notes",
                    from: twelveHoursFromEpoch.addingTimeInterval(60),
                    to: twelveHoursFromEpoch.addingTimeInterval(120)),
                entry(
                    "short project",
                    "short task",
                    String(repeating: "here are some long notes ", count: 3),
                    from: twelveHoursFromEpoch.addingTimeInterval(120),
                    to: twelveHoursFromEpoch.addingTimeInterval(180))
            ]
        }
        let originalWindowFrame = group("Open report in two days") {() -> CGRect in
            dragStatusMenu(to: NSScreen.main!.frame.maxX)
            setTimeUtc(d: 2)
            handleLongSessionPrompt(on: .ptn, .startNewSession)
            // When we start the new session, the PTN will disappear, but the daily report will open (since we're past the scheduled date).
            // Sanity check that the frame's right edge is at the screen's right edge.
            let dailyReportFrame = self.app.windows[WindowType.dailyEnd.windowTitle].firstMatch.frame
            XCTAssertEqual(NSScreen.main!.frame.width, dailyReportFrame.maxX)
            return dailyReportFrame
        }
        group("Set time back") {
            // Our current date is 1/2/1970 00:00:00, and the report starts at the 7am before that. We want the previous day's,
            // which goes from 12/31/1969 07:00:00 to 1/1/1970 00:00:00.
            let dailyReportWindow = app.windows[WindowType.dailyEnd.windowTitle].firstMatch
            XCTAssertTrue(dailyReportWindow.datePickers.firstMatch.hasFocus) // sanity check
            dailyReportWindow.typeKey(.tab) // tab to the date portion, then arrowdown to decrement it
            dailyReportWindow.typeKey(.downArrow)
        }
        group("Confirm that the report has the entry") {
            let dailyReportWindow = app.windows[WindowType.dailyEnd.windowTitle].firstMatch
            let project = HierarchicalEntryLevel(ancestor: dailyReportWindow, scope: "Project", label: longProjectName)
            let firstVisibleElement = project.allElements.values.first(where: {$0.isVisible})
            if let visible = firstVisibleElement {
                log("found: \(visible.simpleDescription)")
            }
            XCTAssertNotNil(firstVisibleElement, "Project not visible")
        }
        group("Check that the window is still within the original bounds") {
            let dailyReportWindow = app.windows[WindowType.dailyEnd.windowTitle].firstMatch
            let dailyReportFrame = dailyReportWindow.frame
            XCTAssertEqual(dailyReportFrame.minX, originalWindowFrame.minX)
            XCTAssertEqual(dailyReportFrame.maxX, originalWindowFrame.maxX)
            let project = HierarchicalEntryLevel(ancestor: dailyReportWindow, scope: "Project", label: longProjectName)
            for (description, e) in project.allElements {
                XCTAssertTrue(e.isVisible, description)
            }
        }
        group("Check the long notes") {
            let (shortTaskElem, longTaskElem) = group("Open project and task") {() -> (XCUIElement, XCUIElement) in
                let dailyReportWindow = app.windows[WindowType.dailyEnd.windowTitle].firstMatch
                let shortProject = HierarchicalEntryLevel(ancestor: dailyReportWindow, scope: "Project", label: "short project")
                shortProject.disclosure.click()
                wait(for: "project to open", until: {dailyReportWindow.groups.count > 0})
                
                let tasksForProject = dailyReportWindow.groups["Tasks for \"short project\""]
                let task = HierarchicalEntryLevel(ancestor: tasksForProject, scope: "Task", label: "short task")
                task.disclosure.click()
                wait(for: "task details to open", until: {tasksForProject.groups.staticTexts.count == 4})
                
                let taskDetails = tasksForProject.groups["Details for short task"]
                // the details texts are: [0] time header for short task, [1] short task text, [2] time header for long task, [3] long task text
                let detailTexts = taskDetails.staticTexts.allElementsBoundByIndex
                return (detailTexts[1], detailTexts[3])
            }
            group("Validate task elements") {
                XCTAssertTrue(shortTaskElem.stringValue.contains("short notes"))
                XCTAssertTrue(longTaskElem.stringValue.contains("here are some long notes"))
                // Make sure the long task height is at least 1.9x the short task height. I would expect it to be 2x, but I'm allowing for
                // rounding layout squashing, etc.
                XCTAssertGreaterThanOrEqual(longTaskElem.frame.height, shortTaskElem.frame.height * 1.9)
            }   
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
