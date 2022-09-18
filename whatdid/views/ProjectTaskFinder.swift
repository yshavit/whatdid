// whatdid?

import Cocoa

class ProjectTaskFinder: WdView {
    var onOpen: () -> (SaveState, [ProjectAndTask]) = {(SaveState.empty, [])}
    var previewSelect: (ProjectAndTask) -> Void = {_ in}
    var onSelect: (ProjectAndTask) -> Void = {_ in}
    var onCancel: (SaveState) -> Void = {_ in}
    
    private let autoCompleteField = AutoCompletingField()
    private var saveState = SaveState.empty
    
    override func wdViewInit() {
        let dismissButton = ButtonWithClosure(label: "dismiss") {_ in self.cancel()}
        dismissButton.bezelStyle = .rounded
        if #available(macOS 11.0, *) {
            if let dismissImage = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "dismiss") {
                dismissButton.image = dismissImage
                dismissButton.imagePosition = .imageOnly
                dismissButton.imageScaling = .scaleProportionallyDown
                dismissButton.isBordered = false
            }
        }
        
        autoCompleteField.optionsLookup = {
            let (saveState, options) = self.onOpen()
            self.autoCompleteField.stringValue = ""
            self.saveState = saveState
            return options.map {pt in
                "\u{11}\(pt.project)\u{11} > \u{11}\(pt.task)\u{11}"
            }
        }
        autoCompleteField.onAction = {f in
            self.parseProjectAndTask(to: self.onSelect)
        }
        autoCompleteField.onTextChange = {
            self.parseProjectAndTask(to: self.previewSelect)
        }
        autoCompleteField.onCancel = {
            self.cancel()
            return true // nothing left to do for next reponder(s)
        }
        autoCompleteField.tracksPopupSelection = true
        autoCompleteField.placeholderString = "enter any project or task"
        
        let stack = NSStackView(
            orientation: .horizontal,
            NSTextField(labelWithString: "find:"),
            autoCompleteField,
            dismissButton
        )
        
        addSubview(stack)
        stack.anchorAllSides(to: self)
    }
    
    private func cancel() {
        onCancel(saveState)
    }
    
    override func becomeFirstResponder() -> Bool {
        return autoCompleteField.becomeFirstResponder()
    }
    
    private func parseProjectAndTask(to handler: (ProjectAndTask) -> Void) {
        let str = autoCompleteField.stringValue
        let splits = str.split(separator: "\u{11}")
        if splits.count >= 3 {
            /// The splits should be:
            /// `[project, " > ", task]`
            let pt = ProjectAndTask(project: String(splits[0]), task: splits.dropFirst(2).joined(separator: ""))
            handler(pt)
        }
    }
    
    struct SaveState {
        let project: String
        let task: String
        let notes: String
        
        static let empty = SaveState(project: "", task: "", notes: "")
    }
}

struct ProjectAndTask {
    let project: String
    let task: String
}
