// whatdidTests?

import XCTest
@testable import Whatdid

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
        XCTAssertEqual(entries, model.listEntries(from: epoch(0), to: epoch(1000)))
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
        XCTAssertEqual(entries, model.listEntries(from: epoch(0), to: epoch(1000)))
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
        XCTAssertEqual(entries, model.listEntries(from: epoch(0), to: epoch(1000)))
    }

    func testRewrite() {
        let model = Model(modelName: "testTasksAreDedupedWithinProject", clearAllEntriesOnStartup: true)
        // Make two of the entries identical; the rewrite should still only affect one of them
        let _ = [
            add(FlatEntry(from: epoch(0), to: epoch(100), project: "proj-a", task: "task-1", notes: nil), to: model),
            add(FlatEntry(from: epoch(0), to: epoch(100), project: "proj-a", task: "task-1", notes: nil), to: model),
            add(FlatEntry(from: epoch(1000), to: epoch(200), project: "proj-a", task: "task-2", notes: "hello"), to: model),
        ]
        let modified = model
                .listEntriesWithIds(from: Date.distantPast, to: Date.distantFuture)
                .first(where: {$0.entry.notes == nil})!
                .map(modify: {$0.replacing(project: "proj-C", task: "task-9", notes: "world")})
        let rewriteFailed = expectation(description: "rewrite failed")
        rewriteFailed.isInverted = true
        let rewriteComplete = expectation(description: "rewrite complete")
        model.rewrite(entries: [modified], andThen: {success in
            if !success {
                rewriteFailed.fulfill()
            }
            rewriteComplete.fulfill()
        })
        wait(for: [rewriteComplete], timeout: 10)
        wait(for: [rewriteFailed], timeout: 1)
        XCTAssertEqualIgnoringOrder([
            add(FlatEntry(from: epoch(0), to: epoch(100), project: "proj-a", task: "task-1", notes: nil), to: model),
            add(FlatEntry(from: epoch(0), to: epoch(100), project: "proj-C", task: "task-9", notes: "world"), to: model),
            add(FlatEntry(from: epoch(1000), to: epoch(200), project: "proj-a", task: "task-2", notes: "hello"), to: model),
        ], model.listEntries(from: Date.distantPast, to: Date.distantFuture))
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
