// whatdid?

import Cocoa
import KeyboardShortcuts

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
        for (i, tab) in mainTabs.tabViewItems.enumerated() {
            let text = tab.label
            let button = ButtonWithClosure(label: text) {_ in
                self.selectPane(at: i)
            }
            button.bezelStyle = .smallSquare
            button.image = tab.value(forKey: "image") as? NSImage
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.setButtonType(.pushOnPushOff)
            button.focusRingType = .none
            button.setAccessibilityRole(.button)
            button.setAccessibilitySubrole(.tabButtonSubrole)
            tabButtonsStack.addArrangedSubview(button)
        }
        tabButtonsStack.addArrangedSubview(NSView()) // trailing spacer
        
        setUpGeneralPanel()
        setUpAboutPanel()
    }
    
    override func viewWillAppear() {
        if !mainTabs.tabViewItems.isEmpty {
            selectPane(at: 0) // TODO rememeber the previously opened one
        }
    }
    
    private func selectPane(at index: Int) {
        for (otherButtonIdx, subview) in self.tabButtonsStack.arrangedSubviews.enumerated() {
            let state: NSControl.StateValue = otherButtonIdx == index ? .on : .off
            (subview as? NSButton)?.state = state
        }
        self.mainTabs.selectTabViewItem(at: index)
        view.layoutSubtreeIfNeeded()
        view.window?.setContentSize(view.fittingSize)
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
    
    private func endParentSheet(with response: NSApplication.ModalResponse) {
        if let myWindow = view.window, let mySheetParent = myWindow.sheetParent {
            mySheetParent.endSheet(myWindow, returnCode: response)
        }
    }
    //------------------------------------------------------------------
    // General
    //------------------------------------------------------------------
    
    @IBOutlet var globalShortcutHolder: NSView!
    
    private func setUpGeneralPanel() {
        let recorder = KeyboardShortcuts.RecorderCocoa(for: .grabFocus)
        globalShortcutHolder.addSubview(recorder)
        recorder.anchorAllSides(to: globalShortcutHolder)
    }
    
    
    //------------------------------------------------------------------
    // ABOUT
    //------------------------------------------------------------------
    
    @IBOutlet var shortVersion: NSTextField!
    @IBOutlet var fullVersion: NSTextField!
    @IBOutlet var shaVersion: NSButton!
    
    private func setUpAboutPanel() {
        shortVersion.stringValue = shortVersion.stringValue.replacingBracketedPlaceholders(with: [
            "version": Version.short
        ])
        fullVersion.stringValue = fullVersion.stringValue.replacingBracketedPlaceholders(with: [
            "fullversion": Version.full
        ])
        shaVersion.title = shaVersion.title.replacingBracketedPlaceholders(with: [
            "sha": Version.gitSha
        ])
        shaVersion.toolTip = shaVersion.toolTip?.replacingBracketedPlaceholders(with: [
            "sha": Version.gitSha.replacingOccurrences(of: ".dirty", with: "")
        ])
    }
    
    //------------------------------------------------------------------
    // OTHER / COMMON
    //------------------------------------------------------------------
    
    /// turns a button into an <a href>, with the link coming from the button's tooltip. Hacky, but easy. :-)
    @IBAction func href(_ sender: NSButton) {
        if let location = sender.toolTip, let url = URL(string: location) {
            NSWorkspace.shared.open(url)
        } else {
            NSLog("invalid href: \(sender.toolTip ?? "<nil>")")
        }
    }
    
}
