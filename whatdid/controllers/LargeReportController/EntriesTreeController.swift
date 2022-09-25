// whatdid?

import Cocoa

@IBDesignable
class EntriesTreeController: NSViewController {

    @IBOutlet weak var treeView: NSOutlineView!
    @IBOutlet weak var sortOptionsMenu: NSMenu!
    private var dataSource: EntriesTreeDataSource!
    
    private var filterString = ""

    var existingNodes: [EntriesTreeDataSource.Node] {
        dataSource.nodes
    }
    
    var isEnabled: Bool {
        get { treeView.isEnabled }
        set { treeView.isEnabled = newValue }
    }
    
    @IBInspectable
    @objc private dynamic var summarySortIndex: Int = 0 {
        didSet {
            if summarySortIndex == oldValue {
                return
            }
            guard let item = sortOptionsMenu.item(at: summarySortIndex),
                  let itemId = item.identifier?.rawValue,
                  let sorting = SortInfo(parsedFrom: itemId, to: EntriesTreeDataSource.SummarySort.init)
            else {
                wdlog(.error, "Couldn't set summarySortIndex=%d. Reverting to %d", summarySortIndex, oldValue)
                summarySortIndex = oldValue
                return
            }
            dataSource.summarySort = sorting
        }
    }
    
    override func viewDidLoad() {
        let summarySource = EntriesTreeDataSource()
        summarySource.onSortDidChange = summarySortChanged
        treeView.dataSource = summarySource
        treeView.delegate = summarySource
        dataSource = summarySource
        summarySortIndex = 1
        summarySortIndex = 0
    }
    
    private func summarySortChanged(newSort summarySort: SortInfo<EntriesTreeDataSource.SummarySort>) -> Bool {
        let itemId = summarySort.asString
        guard let idx = sortOptionsMenu.items.firstIndex(where: {$0.identifier?.rawValue == itemId}) else {
            wdlog(.error, "Couldn't find a sortOptionsMenu.items elem with id=%@", itemId)
            return false
        }
        summarySortIndex = idx
        treeView.sortDescriptors = [NSSortDescriptor(
                key: summarySort.key.rawValue,
                ascending: summarySort.ascending)]
        load(from: createLoader(using: existingNodes))
        return true
    }

    func createLoader(using newEntries: [FlatEntry]) -> Loader {
        createLoader(using: dataSource.createNodes(from: newEntries))
    }
    
    func createLoader(using nodes: [EntriesTreeDataSource.Node]) -> Loader {
        Loader(nodes: dataSource.sort(nodes: nodes))
    }

    func load(from loader: Loader) {
        dataSource.nodes = loader.nodes
        refreshVisibleNodes()
        treeView.reloadData()
    }

    func updateFilter(to string: String) {
        filterString = string
        refreshVisibleNodes()
    }

    private func refreshVisibleNodes() {
        var matched = Set<EntriesTreeDataSource.Node>()
        if filterString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            for node in dataSource.nodes {
                node.forNodeAndDescendants(run: { matched.insert($0) })
            }
        } else {
            let sb = PushableString()
            func isVisible(from node: EntriesTreeDataSource.Node, parentMatched: Bool = false) -> Bool {
                var anyChildrenMatch = false
                var thisNodeMatches = parentMatched

                sb.with(node.title) {
                    if !thisNodeMatches {
                        thisNodeMatches = SubsequenceMatcher.hasMatches(lookFor: filterString, inString: sb.string)
                    }
                    sb.with(" ▸ ") {
                        for child in node.children {
                            if isVisible(from: child, parentMatched: thisNodeMatches) {
                                anyChildrenMatch = true
                                // don't break; we want other children to get a chance to be seen, too
                            }
                        }
                    }
                }
                if !thisNodeMatches {
                    thisNodeMatches = anyChildrenMatch
                }
                if thisNodeMatches {
                    matched.insert(node)
                }
                return thisNodeMatches
            }

            dataSource.nodes.forEach({ _ = isVisible(from: $0) })
        }
        dataSource.visibleNodes = matched

        // Now, refresh the data source
        var hideIndexes = IndexSet()
        var unhideIndexes = IndexSet()
        let currentlyHiddenTreeRows = treeView.hiddenRowIndexes
        for i in 0..<treeView.numberOfRows {
            if let node = treeView.item(atRow: i) as? EntriesTreeDataSource.Node {
                if dataSource.visibleNodes.contains(node) {
                    if currentlyHiddenTreeRows.contains(i) {
                        unhideIndexes.insert(i)
                    }
                } else if !currentlyHiddenTreeRows.contains(i) {
                    hideIndexes.insert(i)
                }
            }
        }
        treeView.unhideRows(at: unhideIndexes, withAnimation: [])
        treeView.hideRows(at: hideIndexes, withAnimation: [])
    }

    struct Loader {
        static let empty = Loader(nodes: [])
        
        fileprivate let nodes: [EntriesTreeDataSource.Node]
    }
}

