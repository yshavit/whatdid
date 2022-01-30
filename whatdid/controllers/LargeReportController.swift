// whatdid?

import Cocoa

class LargeReportController: NSWindowController, NSWindowDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    @IBOutlet weak var tasksTreeView: NSOutlineView!
    @IBOutlet weak var sortOptions: NSPopUpButton!
    @IBOutlet weak var dateRangePicker: DateRangePicker!
    
    static let timeCol = NSUserInterfaceItemIdentifier(rawValue: "timeCol")
    static let descriptionCol = NSUserInterfaceItemIdentifier(rawValue: "descriptionCol")
    
    private var entries = [Node]()
    
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
            createSpinner.leadingAnchor.constraint(equalTo: tasksTreeView.leadingAnchor).isActive = true
            createSpinner.centerYAnchor.constraint(equalTo: tasksTreeView.centerYAnchor).isActive = true
            if #available(macOS 11.0, *) {
                createSpinner.controlSize = .large
            }
        } else {
            spinner = nil
        }
        let ordering = projectAndTaskSortOrder()
        let prevEntries = entries
        entries = []
        tasksTreeView.reloadData()
        DispatchQueue.global().async {
            func progressBar(total: Int, processed: Int) {
                if let spinner = spinner {
                    DispatchQueue.main.async {
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
            let entriesSorted = self.sort(entries: newEntriesUnsorted, by: ordering, progress: progressBar(total:processed:))
            DispatchQueue.main.async {
                self.entries = entriesSorted
                self.tasksTreeView.reloadData()
                if let spinner = spinner {
                    spinner.removeFromSuperview()
                }
                self.setControlsEnabled(true)
            }
        }
    }
    
    private func projectAndTaskSortOrder() -> (Node, Node) -> Bool {
        switch sortOptions.selectedItem?.title {
        case "Most recent":
            return {a, b in a.lastWorkedOn > b.lastWorkedOn}
        case "Least recent":
            return {a, b in a.lastWorkedOn < b.lastWorkedOn}
        case "Least time":
            return {a, b in a.timeSpent < b.timeSpent}
        default: // including "Most time"
            return {a, b in a.timeSpent > b.timeSpent}
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
        case LargeReportController.descriptionCol:
            return NSTextField(labelWithString: item.title)
        default:
            return nil
        }
    }
    
    private func sort(entries: [Node], by newOrder: (Node, Node) -> Bool, progress: (Int, Int) -> Void) -> [Node] {
        let totalElementsToSort = entries.count + entries.reduce(0, {prev, project in prev + project.children.count})
        var elementsSorted = 0
        progress(totalElementsToSort, elementsSorted)
        var newProjects = entries.map { project -> Node in
            let newProject = Node(title: project.title, lastWorkedOn: project.lastWorkedOn, timeSpent: project.timeSpent, children: project.children.sorted(by: newOrder))
            elementsSorted += newProject.children.count
            progress(totalElementsToSort, elementsSorted)
            return newProject
        }
        newProjects.sort(by: newOrder)
        elementsSorted += newProjects.count
        progress(totalElementsToSort, elementsSorted)
        return newProjects
    }
    
    @IBAction func sortChanged(_ sender: Any) {
        loadEntries(fetchingDates: nil)
    }
    
    private func getEntries(from start: Date, to end: Date, progress: (Int, Int) -> Void) -> [Node] {
        func t(_ epochMinutes: Double) -> Date {
            return Date(timeIntervalSince1970: TimeInterval(epochMinutes * 60.0))
        }
        let flatEntries = AppDelegate.instance.model.listEntries(from: start, to: end)
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
                    let fromDesc = TimeUtil.formatSuccinctly(date: entry.from)
                    let toDesc = TimeUtil.formatSuccinctly(date: entry.to, assumingNow: entry.from)
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
    
    private struct Node {
        let title: String
        let lastWorkedOn: Date
        let timeSpent: TimeInterval
        let children: [Node]
    }
}
