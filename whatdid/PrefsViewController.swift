// whatdid?

import Cocoa

class PrefsViewController: NSViewController {
    @IBOutlet private var outerVStackWidth: NSLayoutConstraint!
    @IBOutlet var outerVStackMinHeight: NSLayoutConstraint!
    private var desiredWidth: CGFloat = 0
    private var minHeight: CGFloat = 0
    
    @IBOutlet var tabButtonsStack: NSStackView!
    @IBOutlet var mainTabs: NSTabView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        outerVStackWidth.constant = desiredWidth
        outerVStackMinHeight.constant = minHeight
        
        tabButtonsStack.wantsLayer = true
        tabButtonsStack.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        tabButtonsStack.subviews.forEach {$0.removeFromSuperview()}
        for tab in mainTabs.tabViewItems {
            let text = tab.label
            let button = ButtonWithClosure(label: text) {_ in
                print("hello from \(text)")
            }
            button.bezelStyle = .smallSquare
            button.image = tab.value(forKey: "image") as? NSImage
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.setButtonType(.pushOnPushOff)
            tabButtonsStack.addArrangedSubview(button)
        }
        tabButtonsStack.addArrangedSubview(NSView()) // trailing spacer
    }
    
    func setSize(width: CGFloat, minHeight: CGFloat) {
        self.desiredWidth = width
        self.minHeight = minHeight
    }
    
    @IBAction func quitButton(_ sender: Any) {
        endParentSheet(with: .stop)
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        endParentSheet(with: .cancel)
    }
    
    @IBAction func saveButton(_ sender: Any) {
        endParentSheet(with: .OK)
    }
    
    private func endParentSheet(with response: NSApplication.ModalResponse) {
        if let myWindow = view.window, let mySheetParent = myWindow.sheetParent {
            mySheetParent.endSheet(myWindow, returnCode: response)
        }
    }
}
