// whatdid?

import Cocoa

class ConfirmViewController: NSViewController {
    @IBOutlet weak private var headerField: NSTextField!
    @IBOutlet weak private var detailsField: NSTextField!
    @IBOutlet weak private var minHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak private var widthConstraint: NSLayoutConstraint!
    @IBOutlet weak private var proceedButton: NSButton!
    @IBOutlet weak private var cancelButton: NSButton!
    
    var onProceed = {}
    
    var header: String {
        get {
            headerField.stringValue
        }
        set (value) {
            headerField.stringValue = value
        }
    }
    
    var detail: String {
        get {
            detailsField.stringValue
        }
        set (value) {
            detailsField.stringValue = value
        }
    }
    
    var proceedButtonText: String {
        get {
            proceedButton.title
        }
        set (value) {
            proceedButton.title = value
        }
    }
    
    var cancelButtonText: String {
        get {
            cancelButton.title
        }
        set (value) {
            cancelButton.title = value
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @objc private func handleButton(_ button: NSButton) {
        wdlog(.debug, "handling button: %{public}@", button.title)
    }

    @IBAction func handleProceed(_ sender: Any) {
        onProceed()
        endParentSheet(with: .OK)
    }
    
    @IBAction func handleCancel(_ sender: Any) {
        endParentSheet(with: .cancel)
    }
    
    private func endParentSheet(with response: NSApplication.ModalResponse) {
        if let myWindow = view.window, let mySheetParent = myWindow.sheetParent {
            mySheetParent.endSheet(myWindow, returnCode: response)
        }
    }
    
    func prepareToAttach(to window: NSWindow) -> Action {
        let confirmWindow = NSWindow(contentRect: window.frame, styleMask: [.titled], backing: .buffered, defer: true)
        confirmWindow.backgroundColor = NSColor.windowBackgroundColor
        confirmWindow.contentViewController = self
        confirmWindow.initialFirstResponder = cancelButton
        widthConstraint.constant = window.frame.width
        minHeightConstraint.constant = window.frame.height
        return {
            window.beginSheet(confirmWindow)
            confirmWindow.makeKeyAndOrderFront(self)
        }
    }
    
}
