// whatdid?

import Cocoa

class EditEntriesController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    private var dataSource: EditEntriesDataSource!
    var model: LargeReportEntriesModel?
    
    private var supportsEdits: Bool {
        model is LargeReportEntriesRewriter
    }
    
    // sort options
    @IBOutlet weak var sortOptionsMenu: NSMenu!
    @IBOutlet weak var sortOptionsAscendingMenu: NSPopUpButtonCell!
    @IBInspectable private dynamic var sortAscendingLabel: String = "A - Z"
    @IBInspectable private dynamic var sortDescendingLabel: String = "A - Z"
    
    @IBInspectable private dynamic var sortOptionsIndex: Int = 0 {
        didSet {
            if sortOptionsIndex == oldValue {
                return
            }
            guard let item = sortOptionsMenu.item(at: sortOptionsIndex),
                  let itemId = item.identifier?.rawValue,
                  let sortKey = EditsSort(rawValue: itemId)
            else {
                wdlog(.error, "Couldn't set sortOptionsIndex=%d. Reverting to %d", sortOptionsIndex, oldValue)
                sortOptionsIndex = oldValue
                return
            }
            dataSource.editsSort = SortInfo(key: sortKey, ascending: editSortOptionsIsAscending)
        }
    }
    
    @IBInspectable
    private dynamic var sortOptionsAscendingIndex: Int = 0 {
        didSet {
            if sortOptionsAscendingIndex == oldValue {
                return
            }
            dataSource.editsSort = SortInfo(key: dataSource.editsSort.key, ascending: editSortOptionsIsAscending)
        }
    }

    // the two "bulk edit" fields: one for projects, one for tasks
    @IBOutlet weak var bulkEditProjects: NSTextField!
    @IBOutlet weak var bulkEditTasks: NSTextField!
    
    // edit state
    @IBInspectable private dynamic var hasPendingEdits = false
    
    // selection state
    @IBInspectable private dynamic var selectedIndexes = IndexSet() {
        didSet {
            anySelected = supportsEdits && !selectedIndexes.isEmpty
        }
    }
    @IBInspectable private dynamic var anySelected = false
    
    var existingEntries: [RewriteableFlatEntry] {
        dataSource.entries
    }
    
    var searchAutoCompletes: [String] {
        dataSource.entries
            .map({ProjectAndTask(from: $0.entry)})
            .distinct()
            .map({self.stringOf(projectAndTask: $0)})
            .sorted()
    }
    
    override func viewDidLoad() {
        let editsSource = EditEntriesDataSource(for: tableView)
        editsSource.onSortDidChange = editsSortChanged
        tableView.dataSource = editsSource
        tableView.delegate = editsSource
        dataSource = editsSource
        sortOptionsMenu.items  = tableView.tableColumns.compactMap {column in
            guard let sortKey = column.sortDescriptorPrototype?.key else {
                return nil
            }
            let item = NSMenuItem(title: column.title, action: nil, keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: sortKey)
            return item
        }
        
        editsSource.onDirtyFlagChange = {self.hasPendingEdits = self.supportsEdits && $0}
        
        
        // force a change in both sorts, so that we update the sort descriptors. Not efficient, but easy :)
        dataSource.editsSort = SortInfo(key: EditsSort.editEndTime, ascending: true)
        dataSource.editsSort = SortInfo(key: EditsSort.editEndTime, ascending: false)

    }
    
    @IBAction func saveEdits(_ sender: Any) {
        if !checkForHiddenSelectedRows() {
            return
        }
        if let model = model as? LargeReportEntriesRewriter {
            dataSource.saveAll(to: model)
        } else {
            wdlog(.error, "couldn't save: no model set")
        }
    }
    
    @IBAction func revertEdits(_ sender: Any) {
        if !checkForHiddenSelectedRows() {
            return
        }
        dataSource.clearEdits()
    }

    @IBAction func bulkEditProjects(_ sender: NSTextField) {
        bulkEdit((columnsAt: EditEntriesDataSource.projectHeaderId, to: sender.stringValue))
    }
    
    @IBAction func bulkEditTasks(_ sender: NSTextField) {
        bulkEdit((columnsAt: EditEntriesDataSource.taskHeaderId, to: sender.stringValue))
    }
    
    @IBAction func bulkEdit(_ sender: Any) {
        bulkEdit(
                (columnsAt: EditEntriesDataSource.projectHeaderId, to: bulkEditProjects.stringValue),
                (columnsAt: EditEntriesDataSource.taskHeaderId, to: bulkEditTasks.stringValue))
    }

    private func bulkEdit(_ edits: (columnsAt: NSUserInterfaceItemIdentifier, to: String)...) {
        if !checkForHiddenSelectedRows() {
            return
        }
        for (columnId, newValue) in edits {
            if newValue.isEmpty {
                continue
            }
            let colIdx = tableView.column(withIdentifier: columnId)
            if colIdx < 0 {
                wdlog(.warn, "couldn't find index with id $@", columnId.rawValue)
                return
            }
            let column = tableView.tableColumns[colIdx]
            for row in tableView.selectedRowIndexes {
                dataSource.setField(on: tableView, row: row, column: column, to: newValue)
            }
        }

    }

    private func checkForHiddenSelectedRows() -> Bool {
        if !tableView.selectedRowIndexes.intersection(tableView.hiddenRowIndexes).isEmpty {
            let alert = NSAlert()
            alert.messageText = "Some selected rows are hidden"
            alert.informativeText = "If you continue, those rows will be affected."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Ok")
            let response = alert.runModal()
            return response == .alertSecondButtonReturn
        }
        return true
    }

    private func editsSortChanged(newSort editsSort: SortInfo<EditsSort>) {
        // update the menu indexes
        if let idx = sortOptionsMenu.items.firstIndex(where: {$0.identifier?.rawValue == editsSort.key.rawValue}) {
            sortOptionsIndex = idx
        }
        editSortOptionsIsAscending = editsSort.ascending
        // update the sort descriptors
        tableView.sortDescriptors = [NSSortDescriptor(key: editsSort.key.rawValue, ascending: editsSort.ascending)]
        // update the menu labels
        switch editsSort.key {
        case .editProject, .editTask, .editNotes:
            (sortAscendingLabel, sortDescendingLabel) = ("A - Z", "Z - A")
        case .editStartTime, .editEndTime:
            (sortAscendingLabel, sortDescendingLabel) = ("Earliest first", "Most recent first")
        }
        dataSource.sort()
        tableView.reloadData()
    }

    private var editSortOptionsIsAscending: Bool {
        // Assume that there are exactly two items, and that the top item is ascending.
        // This *is* a safe assumption, unless I change the UI!
        get {
            sortOptionsAscendingIndex == 0
        } set {
            sortOptionsAscendingIndex = newValue ? 0 : 1
        }
    }

    private func stringOf(projectAndTask entry: ProjectAndTask, notes: String? = nil) -> String {
        "\(entry.project) ▸ \(entry.task)\(notes ?? "")"
    }
    
    func createLoader(using newEntries: [RewriteableFlatEntry]) -> Loader {
        var entries = newEntries
        entries.sort(by: self.dataSource.editsSort.sortingFunction)
        return Loader(entries: newEntries)
    }
    
    func load(from loader: Loader) {
        dataSource.entries = loader.entries
        tableView.reloadData()
    }
    
    func updateFilter(to searchText: String) {
        if searchText.isEmpty {
            tableView.unhideRows(at: tableView.hiddenRowIndexes, withAnimation: .slideUp)
            return
        }
        let currentlyHidden = tableView.hiddenRowIndexes
        var toHide = IndexSet()
        var toUnhide = IndexSet()
        for (i, elem) in (dataSource?.entries ?? []).enumerated() {
            let entryString = stringOf(projectAndTask: .init(from: elem.entry), notes: elem.entry.notes)
            if SubsequenceMatcher.matches(lookFor: searchText, inString: entryString).isEmpty {
                toHide.insert(i)
            } else if currentlyHidden.contains(i) {
                toUnhide.insert(i)
            }
        }
        tableView.unhideRows(at: toUnhide, withAnimation: [])
        tableView.hideRows(at: toHide, withAnimation: .slideUp)
        
    }
    
    struct Loader {
        static let empty = Loader(entries: [])
        
        fileprivate let entries: [RewriteableFlatEntry]
    }
}
