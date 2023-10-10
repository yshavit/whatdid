// whatdid?

import Cocoa
import KeyboardShortcuts

class PrefsViewController: NSViewController {
    public static let SHOW_TUTORIAL = NSApplication.ModalResponse(27)
    public static let CLOSE_PTN = NSApplication.ModalResponse(28)
    @Pref(key: "prefsview.openItem") private static var openTab = 0
    
    @IBOutlet private var outerVStackWidth: NSLayoutConstraint!
    @IBOutlet var outerVStackMinHeight: NSLayoutConstraint!
    private var desiredWidth: CGFloat = 0
    private var minHeight: CGFloat = 0
    
    @IBOutlet var tabButtonsStack: NSStackView!
    @IBOutlet var mainTabs: NSTabView!

    // Hooks to general prefs controller
    @IBOutlet var generalPrefsController: PrefsGeneralPaneController!
    var ptnScheduleChanged: () -> Void {
        get {
            generalPrefsController.ptnScheduleChanged
        }
        set {
            generalPrefsController.ptnScheduleChanged = newValue
        }
    }
    var snoozeUntilTomorrowInfo: (hhMm: HoursAndMinutes, includeWeekends: Bool) {
        generalPrefsController.snoozeUntilTomorrowInfo
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        outerVStackWidth.constant = desiredWidth
        outerVStackMinHeight.constant = minHeight
        
        tabButtonsStack.wantsLayer = true
        
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
    }
    
    override func viewDidAppear() {
        UsageTracking.recordAction(.SettingsPaneOpen)
    }
    
    override func viewWillAppear() {
        NSAppearance.withEffectiveAppearance {
            tabButtonsStack.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        if !mainTabs.tabViewItems.isEmpty {
            selectPane(at: PrefsViewController.openTab)
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
        PrefsViewController.openTab = index
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
}
