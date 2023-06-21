// whatdid?

import Cocoa

class EditEntriesDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    static let selectedHeaderId = NSUserInterfaceItemIdentifier("selected")
    static let projectHeaderId = NSUserInterfaceItemIdentifier("project")
    static let taskHeaderId = NSUserInterfaceItemIdentifier("task")
    static let notesHeaderId = NSUserInterfaceItemIdentifier("notes")
    static let startTimeHeaderId = NSUserInterfaceItemIdentifier("startTime")
    static let endTimeHeaderId = NSUserInterfaceItemIdentifier("endTime")

    private let selectedHeaderCell: CheckboxHeaderCell?

    var editsSort = SortInfo(key: EditsSort.editEndTime, ascending: false) {
        didSet {
            if editsSort != oldValue {
                onSortDidChange(editsSort)
            }
        }
    }
    var onSortDidChange: (SortInfo<EditsSort>) -> Void = {_ in}

    var onDirtyFlagChange: (Bool) -> Void = {_ in} {
        didSet {
            onDirtyFlagChange(!modifiedCells.isEmpty)
        }
    }

    private var modifiedCells = [EntryCell:RevertableTextField]() {
        didSet {
            let prevDirty = !oldValue.isEmpty
            let nowDirty = !modifiedCells.isEmpty
            if prevDirty != nowDirty {
                onDirtyFlagChange(nowDirty)
            }
        }
    }

    init(for table: NSTableView) {
        if let selectColumn = table.tableColumns.first(where: {$0.identifier == EditEntriesDataSource.selectedHeaderId}) {
            let selectedHeaderCell = CheckboxHeaderCell()
            selectColumn.headerCell = selectedHeaderCell
            self.selectedHeaderCell = selectedHeaderCell
        } else {
            selectedHeaderCell = nil
        }
    }

    func clearEdits() {
        for field in modifiedCells.values {
            if let orig = field.original {
                field.stringValue = orig
                editComplete(field)
            }
        }
    }

    func sort() {
        entries.sort(by: editsSort.sortingFunction)
    }

    private var cachedCells = [Int:[NSUserInterfaceItemIdentifier:NSView]]()
    var entries = [RewriteableFlatEntry]() {
        didSet {
            cachedCells.removeAll()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    private func findTableSuperview(from view: NSView) -> NSTableView? {
        var curr: NSView? = view
        while curr != nil {
            if let found = curr as? NSTableView {
                return found
            }
            curr = curr?.superview
        }
        return nil
    }

    @objc func checkboxSelected(_ checkbox: NSButton) {
        guard let table = findTableSuperview(from: checkbox) else {
            wdlog(.warn, "couldn't find table from checkbox")
            return
        }
        let row = table.row(for: checkbox)
        var existing = table.selectedRowIndexes
        if checkbox.state == .on {
            existing.insert(row)
        } else {
            existing.remove(row)
        }
        table.selectRowIndexes(existing, byExtendingSelection: false)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else {
            wdlog(.warn, "notification object was not a table")
            return
        }
        let selectedRows = table.selectedRowIndexes
        for i in 0..<entries.count {
            if let but = cachedCells[i]?[EditEntriesDataSource.selectedHeaderId] as? NSButton {
                but.state = selectedRows.contains(i) ? .on : .off
            }
        }

        let desiredState: NSControl.StateValue
        if selectedRows.isEmpty {
            desiredState = .off
        } else if selectedRows.count == entries.count {
            desiredState = .on
        } else {
            desiredState = .mixed
        }
        if let cell = selectedHeaderCell, cell.checkboxState != desiredState {
            cell.checkboxState = desiredState
            table.headerView?.needsDisplay = true
        }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let newDescriptors = tableView.sortDescriptors
        if let firstDescriptor = newDescriptors.first {
            if let descriptorKey = firstDescriptor.key, let descriptorSort = EditsSort(rawValue: descriptorKey) {
                editsSort = SortInfo(key: descriptorSort, ascending: firstDescriptor.ascending)
            } else {
                wdlog(.warn, "Couldn't find sorting order from descriptor with key: %@.", firstDescriptor.key ?? "<nil>")
            }
            if newDescriptors.count > 1 {
                // This seems to be the expected behavior; when you sort a column, it *adds* to the descriptors,
                // it doesn't replace them. But, we turn that into a replace.
                wdlog(.debug, "Found multiple NSSortDescriptors. Using only the first one")
            }
        } else {
            wdlog(.warn, "no new NSSortDescriptors provided.")
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let colId = tableColumn?.identifier, let rowCache = cachedCells[row], let cached = rowCache[colId] {
            return cached
        }

        let str: String
        let editable: Bool
        switch tableColumn?.identifier {
        case EditEntriesDataSource.selectedHeaderId:
            let but = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxSelected(_:)))
            cache(but, at: tableColumn, row)
            return but
        case EditEntriesDataSource.projectHeaderId:
            str = entries[row].entry.project
            editable = true
        case EditEntriesDataSource.taskHeaderId:
            str = entries[row].entry.task
            editable = true
        case EditEntriesDataSource.notesHeaderId:
            str = entries[row].entry.notes ?? ""
            editable = true
        case EditEntriesDataSource.startTimeHeaderId:
            str = TimeUtil.formatSuccinctly(date: entries[row].entry.from)
            editable = false
        case EditEntriesDataSource.endTimeHeaderId:
            str = TimeUtil.formatSuccinctly(date: entries[row].entry.to, assumingNow: entries[row].entry.from)
            editable = false
        default:
            wdlog(.info, "unrecognized column in LargeReportController edits table: %@", tableColumn?.identifier.rawValue ?? "<nil>")
            str = ""
            editable = false
        }
        let view = RevertableTextField(originalValue: str, atRow: row, column: tableColumn?.identifier)
        view.isBordered = false
        view.drawsBackground = false
        view.isEditable = editable
        view.target = self
        view.action = #selector(editComplete(_:))
        cache(view, at: tableColumn, row)
        return view
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        if tableColumn.identifier == EditEntriesDataSource.selectedHeaderId {
            guard let selectedHeaderCell = selectedHeaderCell else {
                return
            }
            // on -> off; off or mixed -> on
            // It could be that the header checkbox is in mixed mode, because only some of the elements are
            // selected — but all the visible ones are. If so, we should treat it as `.on`.
            let allVisibleElemsAreSelected = (selectedHeaderCell.checkboxState == .on)
                    || (tableView.selectedRowIndexes == tableView.visibleRowIndexes)
            if allVisibleElemsAreSelected {
                tableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
            } else {
                tableView.selectRowIndexes(tableView.visibleRowIndexes, byExtendingSelection: false)
            }
        }
    }

    private func cache(_ view: NSView, at tableColumn: NSTableColumn?, _ row: Int) {
        if let colId = tableColumn?.identifier {
            if cachedCells[row] == nil {
                cachedCells[row] = [NSUserInterfaceItemIdentifier:NSView]()
            }
            cachedCells[row]?[colId] = view
        }
    }
    
    func setField(on tableView: NSTableView, row: Int, column: NSTableColumn, to newValue: String) {
        guard let f = self.tableView(tableView, viewFor: column, row: row) as? RevertableTextField else {
            return
        }
        f.stringValue = newValue
        editComplete(f)
    }

    @objc private func editComplete(_ source: RevertableTextField) {
        guard let orig = source.original, let row = source.row, let col = source.column else {
            return
        }
        let myCell = EntryCell(row: row, col: col)
        if source.stringValue == orig {
            source.textColor = NSColor.controlTextColor
            source.toolTip = nil
            modifiedCells.removeValue(forKey: myCell)
        } else {
            source.textColor = NSColor.systemRed
            source.toolTip = "was: \"\(orig)\""
            modifiedCells[myCell] = source
        }
    }

    func saveAll(to model: LargeReportEntriesRewriter) {
        var rewrites = [RewrittenFlatEntry]()
        var dirtyFields = [RevertableTextField]()
        for (rowIdx, entry) in entries.enumerated() {
            guard let row = cachedCells[rowIdx],
                  let project = row[EditEntriesDataSource.projectHeaderId] as? RevertableTextField,
                  let task = row[EditEntriesDataSource.taskHeaderId] as? RevertableTextField,
                  let notes = row[EditEntriesDataSource.notesHeaderId] as? RevertableTextField
            else {
                wdlog(.error, "couldn't find row or column at %d", rowIdx)
                continue
            }
            if project.isChanged || task.isChanged || notes.isChanged {
                rewrites.append(entry.map(modify: {
                    $0.replacing(project: project.stringValue, task: task.stringValue, notes: notes.stringValue)
                }))
                dirtyFields.append(contentsOf: [project, task, notes])
            }
        }

        model.rewrite(entries: rewrites) { success in
            for f in dirtyFields {
                f.original = f.stringValue
                self.editComplete(f)
            }
            wdlog(.info, "wrote entries: success = %d (1 for success, 0 for failed)", success)
        }
    }
}

enum EditsSort: String, SortOrder {
    typealias SortedElement = RewriteableFlatEntry

    case editProject = "editProject"
    case editTask = "editTask"
    case editStartTime = "editStartTime"
    case editEndTime = "editEndTime"
    case editNotes = "editNotes"

    func sortOrder(ascending: Bool) -> (RewriteableFlatEntry, RewriteableFlatEntry) -> Bool {
        switch self {
        case .editProject:
            return createOrdering(lowercased: {$0.entry.project}, ascending: ascending)
        case .editTask:
            return createOrdering(lowercased: {$0.entry.task}, ascending: ascending)
        case .editStartTime:
            return createOrdering(using: {$0.entry.from}, ascending: ascending)
        case .editEndTime:
            return createOrdering(using: {$0.entry.to}, ascending: ascending)
        case .editNotes:
            return createOrdering(lowercased: {$0.entry.notes ?? ""}, ascending: ascending)
        }
    }
}

fileprivate class CheckboxHeaderCell: NSTableHeaderCell {

    private let checkboxCell: NSCell = {
        let cell = NSButtonCell()
        cell.setButtonType(.switch)
        cell.type = .nullCellType
        cell.bezelStyle = .regularSquare
        cell.title = ""
        cell.allowsMixedState = true
        cell.state = .off
        return cell
    }()

    var checkboxState: NSControl.StateValue {
        get {
            checkboxCell.state
        }
        set (state) {
            checkboxCell.state = state
        }
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let centeredRect = CGRect(
                x: cellFrame.midX - checkboxCell.cellSize.width / 2.0,
                y: cellFrame.midY - checkboxCell.cellSize.height / 2.0,
                width: checkboxCell.cellSize.width,
                height: checkboxCell.cellSize.height
        )
        checkboxCell.draw(withFrame: centeredRect, in: controlView)
    }
}

private struct EntryCell: Hashable {
    let row: Int
    let col: NSUserInterfaceItemIdentifier?
}

class RevertableTextField: NSTextField, NSTextFieldDelegate {
    fileprivate var original: String?
    fileprivate var row: Int?
    fileprivate var column: NSUserInterfaceItemIdentifier?

    convenience init(originalValue: String, atRow row: Int, column: NSUserInterfaceItemIdentifier?) {
        self.init(string: originalValue)
        original = originalValue
        self.row = row
        self.column = column
    }

    var isChanged: Bool {
        original != stringValue
    }
}
