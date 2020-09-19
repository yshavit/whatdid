// whatdid?

import Cocoa

class PrefsViewController: NSViewController, NSToolbarDelegate {
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
        for (i, tab) in mainTabs.tabViewItems.enumerated() {
            let text = tab.label
            let button = ButtonWithClosure(label: text) {_ in
                print("hello from \(text)")
                self.mainTabs.selectTabViewItem(at: i)
                for (otherButtonIdx, subview) in self.tabButtonsStack.arrangedSubviews.enumerated() {
                    if otherButtonIdx != i {
                        (subview as? NSButton)?.state = .off
                    }
                }
            }
            button.bezelStyle = .smallSquare
            button.image = tab.value(forKey: "image") as? NSImage
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.setButtonType(.pushOnPushOff)
            button.focusRingType = .none
            tabButtonsStack.addArrangedSubview(button)
        }
        tabButtonsStack.addArrangedSubview(NSView()) // trailing spacer
        if !mainTabs.tabViewItems.isEmpty {
            mainTabs.selectTabViewItem(at: 0) // TODO save which one is selected
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return mainTabs.tabViewItems.map({tab in NSToolbarItem.Identifier(rawValue: tab.label)})
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        print("asking for toolbar: \(itemIdentifier.rawValue)")
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.image = NSImage(named: NSImage.infoName)
        item.label = itemIdentifier.rawValue
        return item
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarAllowedItemIdentifiers(toolbar)
    }
    
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
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
