// whatdid?

import Cocoa

class LargeReportController: NSWindowController, NSWindowDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    @IBOutlet weak var tasksTreeView: NSOutlineView!
    @IBOutlet weak var sortOptions: NSPopUpButton!
    @IBOutlet weak var dateRangePicker: DateRangePicker!
    
    static let timeCol = NSUserInterfaceItemIdentifier(rawValue: "timeCol")
    static let dateCol = NSUserInterfaceItemIdentifier(rawValue: "dateCol")
    static let descriptionCol = NSUserInterfaceItemIdentifier(rawValue: "descriptionCol")
    
    private var entries = [Node]()
    private var sorting = Sorting(by: .timeSpent, ascending: false)
    var modelOverride: Model?
    var loadDataAsynchronously = true
    
    override func windowDidLoad() {
        super.windowDidLoad()
        tasksTreeView.dataSource = self
        tasksTreeView.delegate = self
        dateRangePicker.onDateSelection {start, end, reason in
            guard reason != .initial else {
                return
            }
            self.loadEntries(fetchingDates: (start, end))
        }
        tasksTreeView.sortDescriptors = [NSSortDescriptor(key: sorting.by.rawValue, ascending: sorting.ascending)]
    }
    
    override func showWindow(_ sender: Any?) {
        AppDelegate.instance.windowOpened(self)
        super.showWindow(sender)
        dateRangePicker.prepareToShow()
    }
    
    private func setControlsEnabled(_ enabled: Bool) {
        [sortOptions, tasksTreeView, dateRangePicker].forEach({$0?.isEnabled = enabled})
    }
    
    private func loadEntries(fetchingDates: (Date, Date)?) {
        setControlsEnabled(false)
        let spinner: NSProgressIndicator?
        if let view = window?.contentView {
            let createSpinner = NSProgressIndicator()
            spinner = createSpinner
            createSpinner.style = .spinning
            createSpinner.isIndeterminate = true
            createSpinner.startAnimation(self)
            view.addSubview(createSpinner)
            createSpinner.useAutoLayout()
            createSpinner.setContentHuggingPriority(.defaultLow, for: .horizontal)
            createSpinner.setContentHuggingPriority(.defaultLow, for: .vertical)
            createSpinner.widthAnchor.constraint(equalTo: tasksTreeView.widthAnchor).isActive = true
            createSpinner.centerXAnchor.constraint(equalTo: tasksTreeView.centerXAnchor).isActive = true
            createSpinner.centerYAnchor.constraint(equalTo: tasksTreeView.centerYAnchor).isActive = true
            if #available(macOS 11.0, *) {
                createSpinner.controlSize = .large
            }
        } else {
            spinner = nil
        }
        let sorting = sorting
        let prevEntries = entries
        entries = []
        tasksTreeView.reloadData()
        run(on: DispatchQueue.global()) {
            func progressBar(total: Int, processed: Int) {
                if let spinner = spinner {
                    self.run(on: DispatchQueue.main) {
                        spinner.isIndeterminate = false
                        spinner.minValue = 0
                        spinner.maxValue = Double(total)
                        spinner.doubleValue = Double(processed)
                    }
                }
            }
            let newEntriesUnsorted: [Node]
            if let (fetchStart, fetchEnd) = fetchingDates {
                newEntriesUnsorted = self.getEntries(from: fetchStart, to: fetchEnd, progress: progressBar(total:processed:))
            } else {
                newEntriesUnsorted = prevEntries
            }
            let entriesSorted = self.sort(entries: newEntriesUnsorted, by: sorting, progress: progressBar(total:processed:))
            self.run(on: DispatchQueue.main) {
                self.entries = entriesSorted
                self.tasksTreeView.reloadData()
                if let spinner = spinner {
                    spinner.removeFromSuperview()
                }
                self.setControlsEnabled(true)
            }
        }
    }
    
    private func run(on dispatchQueue: DispatchQueue, _ block: @escaping () -> Void) {
        if loadDataAsynchronously {
            dispatchQueue.async(execute: block)
        } else {
            block()
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        AppDelegate.instance.windowClosed(self)
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return entries.count
        } else if let item = item as? Node {
            return item.children.count
        } else {
            wdlog(.warn, "unrecognized node type (numberOfChildrenOfItem)!")
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return entries[index]
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
        case LargeReportController.timeCol:
            return NSTextField(labelWithString: TimeUtil.daysHoursMinutes(for: item.timeSpent))
        case LargeReportController.dateCol:
            let formatter = DateFormatter()
            var formatComponents = "MMMddhma"
            let cal = DefaultScheduler.instance.calendar
            let currentYear = cal.component(.year, from: DefaultScheduler.instance.now)
            if cal.component(.year, from: item.lastWorkedOn) != currentYear {
                formatComponents = "yyyy" + formatComponents
            }
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: formatComponents, options: 0, locale: nil)
            return NSTextField(labelWithString: formatter.string(from: item.lastWorkedOn))
        case LargeReportController.descriptionCol:
            return NSTextField(labelWithString: item.title)
        default:
            return nil
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let newSorting: Sorting?
        
        let newDescriptors = outlineView.sortDescriptors
        if let firstDescriptor = newDescriptors.first {
            if let descriptorKey = firstDescriptor.key, let descriptorSort = SortBy(rawValue: descriptorKey) {
                newSorting = Sorting(by: descriptorSort, ascending: firstDescriptor.ascending)
            } else {
                wdlog(.warn, "Couldn't find sorting order from descriptor with key: %@.", firstDescriptor.key ?? "<nil>")
                newSorting = nil
            }
            if newDescriptors.count > 1 {
                wdlog(.warn, "Found multiple NSSortDescriptors. Using only the first one")
            }
        } else {
            wdlog(.warn, "no new NSSortDescriptors provided.")
            newSorting = nil
        }
        let resolvedSorting: Sorting
        if let newSorting = newSorting {
            resolvedSorting = newSorting
        } else {
            resolvedSorting = Sorting(by: .timeSpent, ascending: false)
            wdlog(.warn, "using default sorting")
        }
        
        // Set the menu title to the new sorting
        let newMenuTitle = LargeReportController.sortMenuOptions.compactMap({menuTitle, sortOption in
            return (sortOption == resolvedSorting) ? menuTitle : nil
        }).first
        if let newMenuTitle = newMenuTitle {
            sortOptions.selectItem(withTitle: newMenuTitle)
        } else {
            wdlog(.error, "Couldn't find menu title for sorting: (by: %@, ascending: %@)", resolvedSorting.by.rawValue, resolvedSorting.ascending)
        }
        
        // reload
        sorting = resolvedSorting
        loadEntries(fetchingDates: nil)
    }
    
    private func sort(entries: [Node], by newOrder: Sorting, progress: (Int, Int) -> Void) -> [Node] {
        let totalElementsToSort = entries.count + entries.reduce(0, {prev, project in prev + project.children.count})
        var elementsSorted = 0
        progress(totalElementsToSort, elementsSorted)
        var newProjects = entries.map { project -> Node in
            let newProject = Node(title: project.title, lastWorkedOn: project.lastWorkedOn, timeSpent: project.timeSpent, children: project.children.sorted(by: newOrder.areInAscendingOrder))
            elementsSorted += newProject.children.count
            progress(totalElementsToSort, elementsSorted)
            return newProject
        }
        newProjects.sort(by: newOrder.areInAscendingOrder)
        elementsSorted += newProjects.count
        progress(totalElementsToSort, elementsSorted)
        return newProjects
    }
    
    private static let sortMenuOptions = [
        "Oldest": Sorting(by: .lastDate, ascending: true),
        "Newest": Sorting(by: .lastDate, ascending: false),
        "Least time": Sorting(by: .timeSpent, ascending: true),
        "Most time": Sorting(by: .timeSpent, ascending: false)
    ]
    
    @IBAction func sortMenuChanged(_ sender: Any) {
        let newSorting: Sorting?
        if let titleOfSelectedItem = sortOptions.titleOfSelectedItem {
            newSorting = LargeReportController.sortMenuOptions[titleOfSelectedItem]
        } else {
            newSorting = nil
        }
        let resolvedSorting: Sorting
        if let newSorting = newSorting {
            resolvedSorting = newSorting
        } else {
            resolvedSorting = Sorting(by: .timeSpent, ascending: false)
        }
        /// The next line will trigger `outlineView(_ outlineView:, sortDescriptorsDidChange)`
        tasksTreeView.sortDescriptors = [NSSortDescriptor(key: resolvedSorting.by.rawValue, ascending: resolvedSorting.ascending)]
    }
    
    private func getEntries(from start: Date, to end: Date, progress: (Int, Int) -> Void) -> [Node] {
        let flatEntries = (modelOverride ?? AppDelegate.instance.model).listEntries(from: start, to: end)
        let projects = Model.GroupedProjects(from: flatEntries)
        let totalEntries = flatEntries.count
        var processed  = 0
        progress(totalEntries, processed)
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
                    notes.append(Node(title: desc, lastWorkedOn: entryDate, timeSpent: entryTime, children: []))
                    taskTime += entryTime
                    processed += 1
                    taskLastWorkedOn = max(taskLastWorkedOn, entryDate)
                    progress(totalEntries, processed)
                }
                tasks.append(Node(title: task.name, lastWorkedOn: taskLastWorkedOn, timeSpent: taskTime, children: notes))
                projectTime += taskTime
                projectLastWorkedOn = max(projectLastWorkedOn, taskLastWorkedOn)
            }
            projectNodes.append(Node(title: project.name, lastWorkedOn: projectLastWorkedOn, timeSpent: projectTime, children: tasks))
        }
        return projectNodes
    }
    
    struct Node {
        let title: String
        let lastWorkedOn: Date
        let timeSpent: TimeInterval
        
        /// We hide this from tests, because it's hidden from the user (everything else is visible, albeit with various formatting)
        fileprivate let children: [Node]
    }
    
    private enum SortBy: String {
        case timeSpent = "sortTime"
        case lastDate = "sortLatest"
    }
    
    private struct Sorting: Equatable {
        let by: SortBy
        let ascending: Bool
        
        func areInAscendingOrder(_ a: Node, _ b: Node) -> Bool {
            switch by {
            case .timeSpent:
                return keysAreInAscendingOrder(a: a.timeSpent, b: b.timeSpent)
            case .lastDate:
                return keysAreInAscendingOrder(a: a.lastWorkedOn, b: b.lastWorkedOn)
            }
        }
        
        /// Returns whether [a, b] are in ascending order.
        ///
        /// From `sort(by:)`:
        ///
        /// "**areInIncreasingOrder**:
        /// A predicate that returns true if its first argument should be ordered before its second argument"
        private func keysAreInAscendingOrder<T: Comparable>(a: T, b: T) -> Bool {
            if ascending {
                return a < b
            } else {
                return a > b
            }
        }
    }
}
