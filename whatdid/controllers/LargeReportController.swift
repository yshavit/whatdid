// whatdid?

import Cocoa
import SwiftUI

class LargeReportController: NSWindowController, NSWindowDelegate {
    @IBOutlet var summaryController: EntriesTreeController!
    @IBOutlet var editsController: EditEntriesController!
    
    @IBOutlet weak var dateRangePicker: DateRangePicker!
    @IBOutlet weak var mainTabView: NSTabView!
    @IBInspectable dynamic var selectedTab: Any?
    @IBOutlet weak var editsSearchField: AutoCompletingField!

    var model: LargeReportEntriesModel = ModelBasedEntries(model: AppDelegate.instance.model)
    
    var loadDataAsynchronously = true
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        summaryController.viewDidLoad()

        editsController.viewDidLoad()
        editsController.model = model

        // Set up the edits view

        // Set up the search bar
        editsSearchField.placeholderString = "Search entries"
        editsSearchField.emptyOptionsPlaceholder = "(no entries)"
        editsSearchField.optionsLookup = {
            self.editsController.searchAutoCompletes
        }
        editsSearchField.onTextChange = handleSearchField
        editsSearchField.onAction = {_ in self.handleSearchField()}
        
        window?.makeFirstResponder(nil) // we don't want anything focused initially
        
        // Hook up the dateRangerPicker; this will immediately load the initial data, so we want it to be the
        // last thing in this function.
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
        summaryController.isEnabled = enabled
        [dateRangePicker].forEach({$0?.isEnabled = enabled})
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
            createSpinner.widthAnchor.constraint(equalTo: mainTabView.widthAnchor).isActive = true
            createSpinner.centerXAnchor.constraint(equalTo: mainTabView.centerXAnchor).isActive = true
            createSpinner.centerYAnchor.constraint(equalTo: mainTabView.centerYAnchor).isActive = true
            if #available(macOS 11.0, *) {
                createSpinner.controlSize = .large
            }
        } else {
            spinner = nil
        }
        
        let prevEntries = (summaryController.existingNodes, editsController.existingEntries)
        
        func load(_ summaryLoader: EntriesTreeController.Loader, _ editsLoader: EditEntriesController.Loader) {
            summaryController.load(from: summaryLoader)
            editsController.load(from: editsLoader)
        }

        load(.empty, .empty)

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
            var editsLoader: EditEntriesController.Loader
            var summaryLoader: EntriesTreeController.Loader
            if let (fetchStart, fetchEnd) = fetchingDates {
                let newEntries = self.model.fetchRewriteableEntries(from: fetchStart, to: fetchEnd)
                editsLoader = self.editsController.createLoader(using: newEntries)
                summaryLoader = self.summaryController.createLoader(using: newEntries.withoutObjectIds)
            } else {
                editsLoader = self.editsController.createLoader(using: prevEntries.1)
                summaryLoader = self.summaryController.createLoader(using: prevEntries.0)
            }
            self.run(on: DispatchQueue.main) {
                load(summaryLoader, editsLoader)
                if let spinner = spinner {
                    spinner.removeFromSuperview()
                }
                self.setControlsEnabled(true)
            }
        }
    }
    
    private func handleSearchField() {
        let searchText = editsSearchField.stringValue
        summaryController.updateFilter(to: searchText)
        editsController.updateFilter(to: searchText)
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
}

protocol LargeReportEntriesModel {
    func fetchRewriteableEntries(from: Date, to: Date) -> [RewriteableFlatEntry]
}

protocol LargeReportEntriesRewriter {
    func rewrite(entries toWrite: [RewrittenFlatEntry], andThen callback: @escaping (Bool) -> Void)
}

fileprivate struct ModelBasedEntries: LargeReportEntriesModel, LargeReportEntriesRewriter {
    let model: Model
    
    func fetchRewriteableEntries(from fetchStart: Date, to fetchEnd: Date) -> [RewriteableFlatEntry] {
        model.listEntriesWithIds(from: fetchStart, to: fetchEnd)
    }
    
    func rewrite(entries toWrite: [RewrittenFlatEntry], andThen callback: @escaping (Bool) -> Void) {
        model.rewrite(entries: toWrite, andThen: callback)
    }
}
