// whatdid?

import Cocoa
import KeyboardShortcuts

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    public static let DEBUG_DATE_FORMATTER = ISO8601DateFormatter()

    private var _model = Model()
    @IBOutlet weak var mainMenu: MainMenu!
    private var deactivationHooks : Atomic<[() -> Void]> = Atomic(wrappedValue: [])
    
    #if UI_TEST
    private var uiTestWindow: UiTestWindow!
    private var manualTickSchedulerWindow: ManualTickSchedulerWindow!
    private var oldPrefs: [String : Any]?
    #endif
    
    var model: Model {
        _model
    }
    
    #if UI_TEST
    func resetModel() {
        _model = Model()
    }
    #endif
    
    func onDeactivation(_ block: @escaping () -> Void) {
        deactivationHooks.modifyInPlace {arr in
            arr.append(block)
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("Starting whatdid with build %@", Version.pretty)
        #if UI_TEST
        setUpActivator()
        NSLog("initializing UI test hooks")
        manualTickSchedulerWindow = ManualTickSchedulerWindow(with: DefaultScheduler.instance)
        uiTestWindow = UiTestWindow()
        uiTestWindow.show()
        NSApp.setActivationPolicy(.regular) // UI tests can time out on launch() without this
        if let bundleId = Bundle.main.bundleIdentifier {
            oldPrefs = UserDefaults.standard.persistentDomain(forName: bundleId)
            NSLog("Removing old preferences because this is a UI test. Saved \(oldPrefs?.count ?? 0) to restore later.")
            UserDefaults.standard.setPersistentDomain([String: Any](), forName: bundleId)
        }
        #endif
        
        AppDelegate.DEBUG_DATE_FORMATTER.timeZone = DefaultScheduler.instance.timeZone
        
        // Set up the keyboard shortcut
        if !Prefs.keyboardShortcutInitializedOnFirstStartup {
            NSLog("Detected first-time setup. Initializing global shortcut")
            KeyboardShortcuts.setShortcut(KeyboardShortcuts.Shortcut(.x, modifiers: [.command, .shift]), for: .grabFocus)
            Prefs.keyboardShortcutInitializedOnFirstStartup = true
        }
        KeyboardShortcuts.onKeyDown(for: .grabFocus) {
            self.mainMenu.focus()
        }
        
        mainMenu.schedule(.ptn)
        mainMenu.schedule(.dailyEnd)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        #if UI_TEST
        if let bundleId = Bundle.main.bundleIdentifier {
            if let toRestore = oldPrefs {
                NSLog("Restoring old preferences")
                UserDefaults.standard.setPersistentDomain(toRestore, forName: bundleId)
            } else {
                NSLog("No previous preferences to restore")
            }
        }
        #endif
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        let oldHooks = deactivationHooks.getAndSet([])
        oldHooks.forEach {hook in
            hook()
        }
    }
    
    #if UI_TEST
    /// For some reason, we need to override this method for the UI test's `app.activate()` to actually show the windows.
    func applicationDidUnhide(_ notification: Notification) {
        NSLog("Application unhid")
    }
    #endif
    
    func snooze(until date: Date) {
        mainMenu.snooze(until: date)
    }
    
    func unSnooze() {
        mainMenu.unSnooze()
    }
    
    var snoozedUntil: Date? {
        mainMenu.snoozedUntil
    }
    
    static func keyComboString(keyEquivalent: String, keyEquivalentMask: NSEvent.ModifierFlags) -> String {
        var keyAdjusted = keyEquivalent
        var maskAdjusted = keyEquivalentMask
        if keyEquivalent.count == 1, let firstKey = keyEquivalent.first {
            keyAdjusted = keyAdjusted.uppercased()
            if firstKey.isUppercase {
                maskAdjusted = NSEvent.ModifierFlags(arrayLiteral: keyEquivalentMask)
                maskAdjusted.insert(.shift)
            }
        }
        return "\(maskAdjusted)\(keyAdjusted)"
    }
    
    #if UI_TEST
    let activatorStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private func setUpActivator() {
        NSApp.setActivationPolicy(.regular) // so that the windows show up normally
        guard let button = activatorStatusItem.button else {
            fatalError("No activator button")
        }
        button.title = "Activate Whatdid"
        button.target = self
        button.action = #selector(handleActivationStatusItemPress)
    }
    
    @objc private func handleActivationStatusItemPress() {
        NSApp.activate(ignoringOtherApps: true)
    }
    #endif
}
