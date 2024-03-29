// whatdidTests?

import XCTest
@testable import Whatdid

class EntriesTreeControllerTest: ControllerTestBase<EntriesTreeController> {

    func testSortByTimeSpentAscending() throws {
        let controller = createController(withData: {builder in
            builder.add(project: "p1", task: "p1.t1", note: "a", withDuration: 1)
            builder.add(project: "p2", task: "p2.tA", note: "b", withDuration: 2)
            builder.add(project: "p1", task: "p1.t2", note: "c", withDuration: 3)
            builder.add(project: "p1", task: "p1.t1", note: "d", withDuration: 4)
        })
        controller.treeView.sortDescriptors = sortDescriptor(for: controller, column: "Time spent", ascending: true)
        let actualItems = expandAllItems(on: controller.treeView)
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
        controller.treeView.sortDescriptors = sortDescriptor(for: controller, column: "Time spent", ascending: false)
        let actualItems = expandAllItems(on: controller.treeView)
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
    
    func testSortByLastWorkedOnAscending() throws {
        let controller = createController(withData: {builder in
            builder.add(project: "p1", task: "p1.t1", note: "a", withDuration: 1)
            builder.add(project: "p2", task: "p2.tA", note: "b", withDuration: 2)
            builder.add(project: "p1", task: "p1.t2", note: "c", withDuration: 3)
            builder.add(project: "p1", task: "p1.t1", note: "d", withDuration: 4)
        })
        controller.treeView.sortDescriptors = sortDescriptor(for: controller, column: "Last worked on", ascending: true)
        let actualItems = expandAllItems(on: controller.treeView)
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
        controller.treeView.sortDescriptors = sortDescriptor(for: controller, column: "Last worked on", ascending: false)
        let actualItems = expandAllItems(on: controller.treeView)
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
        for column in controller.treeView.tableColumns {
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
        let itemsInSortMenu = controller.sortOptionsMenu.items
        for (i, _) in itemsInSortMenu.enumerated() {
            controller.sortOptionsMenu.performActionForItem(at: i)

            let simpleDescriptors = controller.treeView.sortDescriptors.map(SimpleSortDescriptor.from)
            XCTAssertEqual(1, simpleDescriptors.count)
            foundSortDescriptors.formUnion([simpleDescriptors])
        }

        XCTAssertEqual(itemsInSortMenu.count, foundSortDescriptors.count)
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
    
    private func sortDescriptor(for controller: EntriesTreeController, column columnTitle: String, ascending: Bool) -> [NSSortDescriptor] {
        var result = [NSSortDescriptor]()
        for column in controller.treeView.tableColumns {
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
        if let asNode = rowItem as? EntriesTreeDataSource.Node {
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

    override func load(model: Model, into controller: EntriesTreeController) {
        let loader = controller.createLoader(using: model.listEntries(from: Date.distantPast, to: Date.distantFuture))
        controller.load(from: loader)
    }
    
    override var nibName: String {
        "LargeReportController"
    }

    private struct VisibleNode: Equatable {
        let title: String
        let lastWorkedOn: Date
        let timeSpent: TimeInterval
        let indentationLevel: Int
    }
}
