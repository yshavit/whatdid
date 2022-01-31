// whatdidTests?

import XCTest
@testable import whatdid

class LargeReportControllerTest: XCTestCase {
    
    private var thisMorning: Date!
    private var model: Model!

    override func setUpWithError() throws {
        let uniqueName = name.replacingOccurrences(of: "\\W", with: "", options: .regularExpression)
        thisMorning = TimeUtil.dateForTime(.previous, hh: 9, mm: 00)
        model = Model(modelName: uniqueName, clearAllEntriesOnStartup: true)
        // fetch the (empty set of) entries, to force the model's lazy loading. Otherwise, the unit test's adding of entries can
        // race with the controller's fetching of them, such that they both try to clear out the same set of old files (and
        // whoever gets there second, fails due to those files not being there.)
        let _ = model.listEntries(from: thisMorning, to: DefaultScheduler.instance.now)
        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSortByTimeSpentAscending() throws {
        let controller = createController(withData: {builder in
            builder.add(project: "p1", task: "p1.t1", note: "a", withDuration: 1)
            builder.add(project: "p2", task: "p2.tA", note: "b", withDuration: 2)
            builder.add(project: "p1", task: "p1.t2", note: "c", withDuration: 3)
            builder.add(project: "p1", task: "p1.t1", note: "d", withDuration: 4)
        })
        controller.tasksTreeView.sortDescriptors = sortDescriptor(for: controller, column: "Time spent", ascending: true)
        let actualItems = expandAllItems(on: controller.tasksTreeView)
        let indentedTitles = toIndentedString(actualItems, annotatedBy: {"\(Int($0.timeSpent / 60))m"})
        /// Note: The `a` and `d` notes for the `p1.t1` task are still ordered by when they happened, _not_ by how much time they took
        XCTAssertEqual(
            """
            <2m> p2
              <2m> p2.tA
                <2m> b (9:01 am to 9:03 am)
            <8m> p1
              <3m> p1.t2
                <3m> c (9:03 am to 9:06 am)
              <5m> p1.t1
                <1m> a (9:00 am to 9:01 am)
                <4m> d (9:06 am to 9:10 am)
            """,
            indentedTitles)
    }
    
    func testSortByTimeSpentDescending() throws {
        let controller = createController(withData: {builder in
            builder.add(project: "p1", task: "p1.t1", note: "a", withDuration: 1)
            builder.add(project: "p2", task: "p2.tA", note: "b", withDuration: 2)
            builder.add(project: "p1", task: "p1.t2", note: "c", withDuration: 3)
            builder.add(project: "p1", task: "p1.t1", note: "d", withDuration: 4)
        })
        controller.tasksTreeView.sortDescriptors = sortDescriptor(for: controller, column: "Time spent", ascending: false)
        let actualItems = expandAllItems(on: controller.tasksTreeView)
        let indentedTitles = toIndentedString(actualItems, annotatedBy: {"\(Int($0.timeSpent / 60))m"})
        XCTAssertEqual(
            """
            <8m> p1
              <5m> p1.t1
                <1m> a (9:00 am to 9:01 am)
                <4m> d (9:06 am to 9:10 am)
              <3m> p1.t2
                <3m> c (9:03 am to 9:06 am)
            <2m> p2
              <2m> p2.tA
                <2m> b (9:01 am to 9:03 am)
            """,
            indentedTitles)
    }
    
    func testSortByLastWorkedOnAcending() throws {
        let controller = createController(withData: {builder in
            builder.add(project: "p1", task: "p1.t1", note: "a", withDuration: 1)
            builder.add(project: "p2", task: "p2.tA", note: "b", withDuration: 2)
            builder.add(project: "p1", task: "p1.t2", note: "c", withDuration: 3)
            builder.add(project: "p1", task: "p1.t1", note: "d", withDuration: 4)
        })
        controller.tasksTreeView.sortDescriptors = sortDescriptor(for: controller, column: "Last worked on", ascending: true)
        let actualItems = expandAllItems(on: controller.tasksTreeView)
        let indentedTitles = toIndentedString(actualItems, annotatedBy: {"T\(t($0.lastWorkedOn))"})
        /// Note: Notes within a task are always ordered with oldest on top
        XCTAssertEqual(
            """
            <T3> p2
              <T3> p2.tA
                <T3> b (9:01 am to 9:03 am)
            <T10> p1
              <T6> p1.t2
                <T6> c (9:03 am to 9:06 am)
              <T10> p1.t1
                <T1> a (9:00 am to 9:01 am)
                <T10> d (9:06 am to 9:10 am)
            """,
            indentedTitles)
    }
    
    func testSortByLastWorkedOnDescending() throws {
        let controller = createController(withData: {builder in
            builder.add(project: "p1", task: "p1.t1", note: "a", withDuration: 1)
            builder.add(project: "p2", task: "p2.tA", note: "b", withDuration: 2)
            builder.add(project: "p1", task: "p1.t2", note: "c", withDuration: 3)
            builder.add(project: "p1", task: "p1.t1", note: "d", withDuration: 4)
        })
        controller.tasksTreeView.sortDescriptors = sortDescriptor(for: controller, column: "Last worked on", ascending: false)
        let actualItems = expandAllItems(on: controller.tasksTreeView)
        let indentedTitles = toIndentedString(actualItems, annotatedBy: {"T\(t($0.lastWorkedOn))"})
        /// Note: Notes within a task are always ordered with oldest on top
        XCTAssertEqual(
            """
            <T10> p1
              <T10> p1.t1
                <T1> a (9:00 am to 9:01 am)
                <T10> d (9:06 am to 9:10 am)
              <T6> p1.t2
                <T6> c (9:03 am to 9:06 am)
            <T3> p2
              <T3> p2.tA
                <T3> b (9:01 am to 9:03 am)
            """,
            indentedTitles)
    }
    
    func testSortableColumnTitles() {
        let controller = createController(withData: {_ in})
        
        var actualTitles = [String]()
        for column in controller.tasksTreeView.tableColumns {
            if column.sortDescriptorPrototype?.key != nil {
                actualTitles.append(column.title)
            }
        }
        actualTitles.sort() // We don't care about the order
        
        XCTAssertEqual(["Last worked on", "Time spent"], actualTitles)
    }
    
    /// Each menu item in the "sort by" popup button should correspond to a unique sort descriptor.
    func testMenuItemsChangeSorting() {
        struct SimpleSortDescriptor: Hashable {
            let key: String?
            let ascending: Bool
            
            static func from(_ fullDesc: NSSortDescriptor) -> SimpleSortDescriptor {
                return SimpleSortDescriptor(key: fullDesc.key, ascending: fullDesc.ascending)
            }
        }
        let controller = createController(withData: {_ in})
        var foundSortDescriptors = Set<[SimpleSortDescriptor]>()
        let itemsInSortMenu = controller.sortOptions.itemArray
        for item in itemsInSortMenu {
            controller.sortOptions.select(item)
            sendActionToTarget(of: controller.sortOptions)
            
            let simpleDescriptors = controller.tasksTreeView.sortDescriptors.map(SimpleSortDescriptor.from)
            XCTAssertEqual(1, simpleDescriptors.count)
            foundSortDescriptors.formUnion([simpleDescriptors])
        }
        
        XCTAssertEqual(itemsInSortMenu.count, foundSortDescriptors.count)
    }
    
    func testDateRangePicker() {
        let controller = createController(withData: {builder in
            builder.eventOffset = -86400 // start 24 hours ago
            
            for i in 0..<20 {
                // Create 5 days' worth of 6-hour projects
                builder.add(project: "project-\(i)", task: "task", note: "", withDuration: 6 * 60)
            }
        })
        controller.tasksTreeView.sortDescriptors = sortDescriptor(for: controller, column: "Last worked on", ascending: true)
        let treeView = controller.tasksTreeView!
        
        func projectTitlesWithDefaultDateRange() -> [String] {
            return (1..<treeView.numberOfRows).map({
                visibleNode(for: treeView.item(atRow: $0), in: treeView).title
            })
        }
        
        XCTAssertEqual(
            ["project-5", "project-6", "project-7", "project-8"],
            projectTitlesWithDefaultDateRange())
        
        // Now, set the date range picker back to yesterday
        controller.dateRangePicker.selectItem(withTitle: "yesterday")
        sendActionToTarget(of: controller.dateRangePicker)
        XCTAssertEqual(
            ["project-1", "project-2", "project-3", "project-4"],
            projectTitlesWithDefaultDateRange())
    }
    
    private func createController(withData dataLoader: (DataBuilder) -> Void) -> LargeReportController {
        let dataBuilder = DataBuilder(using: model, startingAt: thisMorning)
        dataLoader(dataBuilder)
        
        // Wait until we have as many entries as our DataBuilder expects
        let timeoutAt = Date().addingTimeInterval(3)
        while model.listEntries(from: Date.distantPast, to: Date.distantFuture).count < dataBuilder.expected {
            usleep(50000)
            XCTAssertLessThan(Date(), timeoutAt)
        }
        
        let controller = LargeReportController(windowNibName: NSNib.Name("LargeReportController"))
        controller.loadDataAsynchronously = false
        controller.modelOverride = model
        controller.showWindow(nil)
        return controller
    }
    
    private func expandAllItems(on view: NSOutlineView) -> [VisibleNode] {
        var seenNodes = [VisibleNode]()
        while seenNodes.count < view.numberOfRows {
            // seenNodes.count represents how many nodes we've already seen; this means that it's the index of the first unseen
            // row. Add the row's item, and expand the row if applicable
            let rowItem = view.item(atRow: seenNodes.count)
            if view.isExpandable(rowItem) {
                view.expandItem(rowItem)
            }
            seenNodes.append(visibleNode(for: rowItem, in: view))
        }
        return seenNodes
    }
    
    private func sendActionToTarget(of control: NSControl) {
        control.sendAction(control.action, to: control.target)
    }
    
    private func sortDescriptor(for controller: LargeReportController, column columnTitle: String, ascending: Bool) -> [NSSortDescriptor] {
        var result = [NSSortDescriptor]()
        for column in controller.tasksTreeView.tableColumns {
            if column.title == columnTitle, let columnSortKey = column.sortDescriptorPrototype?.key {
                result.append(NSSortDescriptor(key: columnSortKey, ascending: ascending))
            }
        }
        XCTAssertEqual(1, result.count)
        return result
    }

    private func t(_ minutes: Int) -> Date {
        return thisMorning.addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    func t(_ date: Date) -> Int {
        return Int(date.timeIntervalSince(thisMorning) / 60.0)
    }
    
    private func toIndentedString(_ nodes: [VisibleNode], annotatedBy annotation: (VisibleNode) -> String) -> String {
        return nodes.map({
            let indentation = String(repeating: "  ", count: $0.indentationLevel)
            return "\(indentation)<\(annotation($0))> \($0.title)"
        }).joined(separator: "\n")
    }
    
    private func visibleNode(for rowItem: Any?, in view: NSOutlineView) -> VisibleNode {
        if let asNode = rowItem as? LargeReportController.Node {
            return VisibleNode(
                title: asNode.title,
                lastWorkedOn: asNode.lastWorkedOn,
                timeSpent: asNode.timeSpent,
                indentationLevel: view.level(forItem: rowItem))
        } else {
            XCTFail("item was not a Node: \(rowItem.debugDescription)")
            let fail: VisibleNode? = nil
            return fail!
        }
    }
    
    private class DataBuilder {
        private let model: Model
        private let startingAt: Date
        private var lastEventOffset = TimeInterval(0)
        private(set) var expected = 0
        /// An offset that's applied to all events (after you set this; it's not retroactive).
        var eventOffset = TimeInterval(0)
        
        init(using model: Model, startingAt: Date) {
            self.model = model
            self.startingAt = startingAt
        }
        
        func add(project: String, task: String, note: String, withDuration minutes: Int) {
            let thisTaskDuration = TimeInterval(minutes * 60)
            let from = startingAt.addingTimeInterval(lastEventOffset + eventOffset)
            let to = from.addingTimeInterval(thisTaskDuration)
            let entry = FlatEntry(from: from, to: to, project: project, task: task, notes: note)
            model.add(entry, andThen: {})
            lastEventOffset += thisTaskDuration
            expected += 1
        }
    }
    
    private struct VisibleNode: Equatable {
        let title: String
        let lastWorkedOn: Date
        let timeSpent: TimeInterval
        let indentationLevel: Int
    }
}
