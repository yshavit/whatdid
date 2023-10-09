// whatdid?

import Cocoa
import KeyboardShortcuts
#if canImport(Sparkle)
import Sparkle
#endif

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
    
    @IBInspectable
    dynamic var autoCheckUpdates: Bool {
        get {
            #if canImport(Sparkle)
            AppDelegate.instance.updaterController.updater.automaticallyChecksForUpdates
            #else
            // This var gets read (via binding) at controller load, before we have a chance to remove the updater options stack.
            // That means we do expect it to get invoked even if there's no Sparkle.
            false
            #endif
        }
        set (value) {
            #if canImport(Sparkle)
            AppDelegate.instance.updaterController.updater.automaticallyChecksForUpdates = value
            #else
            wdlog(.error, "improperly invoked autoCheckUpdates:set without sparkle available")
            #endif
        }
    }
    
    @IBInspectable
    dynamic var includeAlphaReleases: Bool {
        get {
            #if canImport(Sparkle)
            Prefs.updateChannels.contains(.alpha)
            #else
            // This var gets read (via binding) at controller load, before we have a chance to remove the updater options stack.
            // That means we do expect it to get invoked even if there's no Sparkle.
            false
            #endif
        }
        set (shouldIncludeAlphas) {
            #if canImport(Sparkle)
            var newChannels = Prefs.updateChannels
            if shouldIncludeAlphas {
                newChannels.formUnion([.alpha])
            } else {
                newChannels.subtract([.alpha])
            }
            Prefs.updateChannels = newChannels
            #else
            wdlog(.error, "improperly invoked includeAlphaReleases:set without sparkle available")
            #endif
        }
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
        
        setUpHelpAndFeedbackPanel()
        setUpAboutPanel()
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
    
    //------------------------------------------------------------------
    // HELP & FEEDBACK
    //------------------------------------------------------------------
    
    @IBOutlet var feedbackButton: NSButton!
    
    private func setUpHelpAndFeedbackPanel() {
        if let versionQuery = Version.pretty.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            feedbackButton.toolTip = feedbackButton.toolTip?.replacingBracketedPlaceholders(with: [
                "version": versionQuery
            ])
        } else {
            feedbackButton.removeFromSuperview()
        }
    }
    
    @IBAction func showTutorial(_ sender: Any) {
        endParentSheet(with: PrefsViewController.SHOW_TUTORIAL)
    }
    
    //------------------------------------------------------------------
    // ABOUT
    //------------------------------------------------------------------
    
    @IBOutlet var shortVersion: NSTextField!
    @IBOutlet var copyright: NSTextField!
    @IBOutlet var fullVersion: NSTextField!
    @IBOutlet var shaVersion: NSButton!
    @IBOutlet var githubShaInfo: NSStackView!
    @IBOutlet weak var updaterOptions: NSStackView!
    
    private func setUpAboutPanel() {
        shortVersion.stringValue = shortVersion.stringValue.replacingBracketedPlaceholders(with: [
            "version": Version.short
        ])
        copyright.stringValue = copyright.stringValue.replacingBracketedPlaceholders(with: [
            "copyright": Version.copyright
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
        githubShaInfo.isHidden = !NSEvent.modifierFlags.contains(.command)
        #if !canImport(Sparkle)
        updaterOptions.removeFromSuperview()
        updaterOptions = nil
        #endif
    }
    
    @IBAction func checkUpdateNow(_ sender: Any) {
        #if canImport(Sparkle)
        AppDelegate.instance.updaterController.checkForUpdates(sender)
        #else
        wdlog(.error, "improperly invoked checkUpdateNow without sparkle available")
        #endif
    }
    
    //------------------------------------------------------------------
    // OTHER / COMMON
    //------------------------------------------------------------------
    
    /// turns a button into an <a href>, with the link coming from the button's tooltip. Hacky, but easy. :-)
    @IBAction func href(_ sender: NSButton) {
        if let location = sender.toolTip, let url = URL(string: location) {
            NSWorkspace.shared.open(url)
        } else {
            wdlog(.warn, "invalid href: %@", sender.toolTip ?? "<nil>")
        }
    }
    
}
