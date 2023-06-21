// whatdid?

import Cocoa

class EntriesTreeDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {

    private static let timeCol = NSUserInterfaceItemIdentifier(rawValue: "timeCol")
    private static let dateCol = NSUserInterfaceItemIdentifier(rawValue: "dateCol")
    private static let descriptionCol = NSUserInterfaceItemIdentifier(rawValue: "descriptionCol")

    var nodes = [Node]()
    var visibleNodes = Set<Node>()

    var summarySort = SortInfo(key: SummarySort.summaryAge, ascending: false) {
        didSet {
            if summarySort != oldValue, !onSortDidChange(summarySort) {
                summarySort = oldValue
            }
        }
    }
    var onSortDidChange: (SortInfo<SummarySort>) -> Bool = {_ in true}

    func createNodes(from flatEntries: [FlatEntry]) -> [Node] {
        let projects = Model.GroupedProjects(from: flatEntries)
        var projectNodes = [Node]()
        projects.forEach {project in
            var tasks = [Node]()
            var projectTime = 0.0
            var projectLastWorkedOn = Date.distantPast
            project.forEach { task in
                var notes = [Node]()
                var taskTime = 0.0
                var taskLastWorkedOn = Date.distantPast
                task.forEach { entry in
                    let fromDesc = TimeUtil.formatSuccinctly(date: entry.from, assumingNow: entry.to)
                    let toDesc = TimeUtil.formatSuccinctly(date: entry.to, assumingNow: entry.to)
                    var entryNotes = entry.notes?.trimmingCharacters(in: .whitespaces) ?? ""
                    if entryNotes.isEmpty {
                        entryNotes = "no notes entered"
                    }
                    let desc = "\(entryNotes) (\(fromDesc) to \(toDesc))"
                    let entryTime = entry.to.timeIntervalSince(entry.from)
                    let entryDate = entry.to
                    notes.append(Node(title: desc, lastWorkedOn: entryDate, timeSpent: entryTime, entry: entry, children: []))
                    taskTime += entryTime
                    taskLastWorkedOn = max(taskLastWorkedOn, entryDate)
                }
                tasks.append(Node(title: task.name, lastWorkedOn: taskLastWorkedOn, timeSpent: taskTime, entry: nil, children: notes))
                projectTime += taskTime
                projectLastWorkedOn = max(projectLastWorkedOn, taskLastWorkedOn)
            }
            projectNodes.append(Node(title: project.name, lastWorkedOn: projectLastWorkedOn, timeSpent: projectTime, entry: nil, children: tasks))
        }
        return projectNodes
    }

    func sort(nodes: [Node]) -> [Node] {
        sort(entries: nodes, by: summarySort)
    }

    private func sort(entries: [Node], by newOrder: SortInfo<SummarySort>) -> [Node] {
        var newProjects = entries.map { project -> Node in
            let newProject = Node(
                    title: project.title,
                    lastWorkedOn: project.lastWorkedOn,
                    timeSpent: project.timeSpent,
                    entry: project.entry,
                    children: project.children.sorted(by: newOrder.sortingFunction))
            return newProject
        }
        newProjects.sort(by: newOrder.sortingFunction)
        return newProjects
    }

    func outlineView(_ outlineView: NSOutlineView, didAdd rowView: NSTableRowView, forRow row: Int) {
        if let node = outlineView.item(atRow: row) as? Node {
            if !visibleNodes.contains(node) {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
                    outlineView.hideRows(at: IndexSet(integer: row))
                }
            }
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return nodes.count
        } else if let item = item as? Node {
            return item.children.count
        } else {
            wdlog(.warn, "unrecognized node type (numberOfChildrenOfItem)!")
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return nodes[index]
        } else if let item = item as? Node {
            return item.children[index]
        } else {
            wdlog(.warn, "unrecognized node type (ofItem)!")
            return "error"
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? Node {
            return !item.children.isEmpty
        } else {
            wdlog(.warn, "unrecognized node type (isItemExpandable)!")
            return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let tableColumn = tableColumn, let item = item as? Node else {
            wdlog(.warn, "unrecognized item or column")
            return nil
        }
        switch tableColumn.identifier {
        case EntriesTreeDataSource.timeCol:
            return NSTextField(labelWithString: TimeUtil.daysHoursMinutes(for: item.timeSpent))
        case EntriesTreeDataSource.dateCol:
            let formatter = DateFormatter()
            var formatComponents = "MMMddhma"
            let cal = DefaultScheduler.instance.calendar
            let currentYear = cal.component(.year, from: DefaultScheduler.instance.now)
            if cal.component(.year, from: item.lastWorkedOn) != currentYear {
                formatComponents = "yyyy" + formatComponents
            }
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: formatComponents, options: 0, locale: nil)
            return NSTextField(labelWithString: formatter.string(from: item.lastWorkedOn))
        case EntriesTreeDataSource.descriptionCol:
            return NSTextField(labelWithString: item.title)
        default:
            return nil
        }
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let newDescriptors = outlineView.sortDescriptors
        if let firstDescriptor = newDescriptors.first {
            if let descriptorKey = firstDescriptor.key, let descriptorSort = SummarySort(rawValue: descriptorKey) {
                summarySort = SortInfo(key: descriptorSort, ascending: firstDescriptor.ascending)
            } else {
                wdlog(.warn, "Couldn't find sorting order from descriptor with key: %@.", firstDescriptor.key ?? "<nil>")
            }
            if newDescriptors.count > 1 {
                wdlog(.warn, "Found multiple NSSortDescriptors. Using only the first one")
            }
        } else {
            wdlog(.warn, "no new NSSortDescriptors provided.")
        }
    }

    struct Node: Hashable {
        private static var idGen = Atomic<Int>(wrappedValue: 0)
        fileprivate let id = Node.idGen.mapAndGet({$0 + 1})
        internal let title: String
        internal let lastWorkedOn: Date
        internal let timeSpent: TimeInterval
        internal let entry: FlatEntry?
        internal let children: [Node]

        fileprivate func countEntriesIncludingDescendants() -> Int {
            var count = 0
            forEntryOnNodeAndDescendants(run: {_ in count += 1 })
            return count
        }

        fileprivate func getEntriesIncludingDescendants() -> [FlatEntry] {
            var output = [FlatEntry]()
            output.reserveCapacity(countEntriesIncludingDescendants())
            forEntryOnNodeAndDescendants { output.append($0) };
            return output
        }

        fileprivate func forEntryOnNodeAndDescendants(run action: (FlatEntry) -> Void) {
            forNodeAndDescendants { node in
                if let entry = node.entry {
                    action(entry)
                }
            }
        }

        func forNodeAndDescendants(run action: (Node) -> Void) {
            action(self)
            for child in children {
                child.forNodeAndDescendants(run: action)
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func ==(lhs: Node, rhs: Node) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            return true
        }
    }

    enum SummarySort: String, SortOrder {
        typealias SortedElement = Node

        case summaryTime = "summaryTime"
        case summaryAge = "summaryAge"

        func sortOrder(ascending: Bool) -> (Node, Node) -> Bool {
            switch self {
            case .summaryAge:
                return createOrdering(using: {$0.lastWorkedOn}, ascending: ascending)
            case .summaryTime:
                return createOrdering(using: {$0.timeSpent}, ascending: ascending)
            }
        }
    }
}

