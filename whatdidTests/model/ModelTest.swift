// whatdidTests?

import XCTest
@testable import whatdid

class ModelTest: XCTestCase {

    func testTasksAreIsolatedBetweenProjects() {
        let model = Model(modelName: "testTasksAreIsolatedBetweenProjects", clearAllEntriesOnStartup: true)
        let sameTask = "same task"
        let entries = [
            add(FlatEntry(from: epoch(0), to: epoch(300), project: "alpha", task: sameTask, notes: "first"), to: model),
            add(FlatEntry(from: epoch(300), to: epoch(400), project: "bravo", task: sameTask, notes: "second"), to: model)]
        let projects = model.listProjects()
        XCTAssertEqual(["bravo", "alpha"], projects)
        for project in projects {
            XCTAssertEqual([sameTask], model.listTasks(project: project), "for project \"\(project)\"")
        }
        XCTAssertEqual(entries.reversed(), model.listEntries(since: epoch(0)))
    }
    
    func testProjectsAreDeduped() {
        let model = Model(modelName: "testProjectsAreDeduped", clearAllEntriesOnStartup: true)
        let sameProject = "same project"
        let entries = [
            add(FlatEntry(from: epoch(0), to: epoch(300), project: sameProject, task: "one", notes: "first"), to: model),
            add(FlatEntry(from: epoch(300), to: epoch(400), project: sameProject, task: "two", notes: "second"), to: model)]
        let projects = model.listProjects()
        XCTAssertEqual([sameProject], projects)
        for project in projects {
            XCTAssertEqual(["two", "one"], model.listTasks(project: project), "for project \"\(project)\"")
        }
        XCTAssertEqual(entries.reversed(), model.listEntries(since: epoch(0)))
    }

    func testTasksAreDedupedWithinProject() {
        let model = Model(modelName: "testTasksAreDedupedWithinProject", clearAllEntriesOnStartup: true)
        let sameProject = "same project"
        let sameTask = "same task"
        let entries = [
            add(FlatEntry(from: epoch(0), to: epoch(300), project: sameProject, task: sameTask, notes: "first"), to: model),
            add(FlatEntry(from: epoch(300), to: epoch(400), project: sameProject, task: sameTask, notes: "second"), to: model)]
        let projects = model.listProjects()
        XCTAssertEqual([sameProject], projects)
        for project in projects {
            XCTAssertEqual([sameTask], model.listTasks(project: project), "for project \"\(project)\"")
        }
        XCTAssertEqual(entries.reversed(), model.listEntries(since: epoch(0)))
    }
    
    private func add(_ entry: FlatEntry, to model: Model) -> FlatEntry {
        let saveExpectation = expectation(description: "save completed")
        model.add(entry, andThen: saveExpectation.fulfill)
        wait(for: [saveExpectation], timeout: 10)
        return entry
    }
    
    private func epoch(_ seconds: Int) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

}
