// whatdid?

import Cocoa
import KeyboardShortcuts
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    public static let DEBUG_DATE_FORMATTER = ISO8601DateFormatter()

    private var _model = Model()
    @IBOutlet weak var mainMenu: MainMenu!
    private var deactivationHooks : Atomic<[() -> Void]> = Atomic(wrappedValue: [])
    
    #if UI_TEST
    private var uiTestWindow: UiTestWindow!
    private var oldPrefs: [String : Any]?
    #endif
    
    var model: Model {
        _model
    }
    
    #if UI_TEST
    func resetModel() {
        _model = Model(emptyCopyOf: _model)
    }
    
    func resetAll() {
        // The scheduler has to get reset first, because various things depend on it:
        // 1) The mainMenu has scheduled actions that we don't want to run (just to save time).
        // 2) The model has its `lastEntryDate`
        // 3) And of course, we have the various PTN/day-start/day-end schedules.
        DefaultScheduler.instance.reset()
        mainMenu.reset()
        resetModel()
        kickOffInitialSchedules()
        resetAllPrefs()
        globalLogHook.reset()
    }
    #endif
    
    func onDeactivation(_ block: @escaping () -> Void) {
        deactivationHooks.modifyInPlace {arr in
            arr.append(block)
        }
    }
    
    func applicationDidFinishLaunching(_: Notification) {
        wdlog(.info, "Starting whatdid with build %@", Version.pretty)
        #if UI_TEST
        NSApp.setActivationPolicy(.regular) // so that the windows show up normally
        wdlog(.info, "initializing UI test hooks")
        uiTestWindow = UiTestWindow()
        uiTestWindow.show()
        NSApp.setActivationPolicy(.regular) // UI tests can time out on launch() without this
        if let bundleId = Bundle.main.bundleIdentifier {
            oldPrefs = UserDefaults.standard.persistentDomain(forName: bundleId)
            wdlog(.info, "Removing old preferences because this is a UI test. Saved %d to restore later.", oldPrefs?.count ?? 0)
            UserDefaults.standard.setPersistentDomain([String: Any](), forName: bundleId)
        }
        #endif
        
        AppDelegate.DEBUG_DATE_FORMATTER.timeZone = DefaultScheduler.instance.timeZone
        
        // Set up the keyboard shortcut
        KeyboardShortcuts.onKeyDown(for: .grabFocus, action: self.mainMenu.focus)
        // Set up the lanch-on-login functionality, if needed
        setUpLauncher()
        // Kick off the various scheduled popups (PTN, day start, day end).
        kickOffInitialSchedules()
    }
    
    private func kickOffInitialSchedules() {
        mainMenu.schedule(.ptn)
        mainMenu.schedule(.dailyEnd)
        mainMenu.schedule(.dayStart)
        
        let currentVersion = Prefs.tutorialVersion
        if SHOW_TUTORIAL_ON_FIRST_START && currentVersion < PtnViewController.CURRENT_TUTORIAL_VERSION {
            mainMenu.whenPtnIsReady {ptn in
                self.mainMenu.open(.ptn, reason: .manual)
                ptn.showTutorial(forVersion: currentVersion)
            }
            Prefs.tutorialVersion = PtnViewController.CURRENT_TUTORIAL_VERSION
        }
        
        if let currentSession = model.getCurrentSession(), let sessionStart = currentSession.startTime {
            // Check to see if the session is earlier than the start of today. If so, start a new session
            let dayStart = Prefs.dayStartTime.map { hh, mm in TimeUtil.dateForTime(.previous, hh: hh, mm: mm) }
            if sessionStart < dayStart {
                mainMenu.whenPtnIsReady {_ in
                    self.mainMenu.open(.dayStart, reason: .scheduled)
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        #if UI_TEST
        if let bundleId = Bundle.main.bundleIdentifier {
            if let toRestore = oldPrefs {
                wdlog(.info, "Restoring old preferences")
                UserDefaults.standard.setPersistentDomain(toRestore, forName: bundleId)
            } else {
                wdlog(.info, "No previous preferences to restore")
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
    
    private func setUpLauncher() {
        // Taken from https://theswiftdev.com/how-to-launch-a-macos-app-at-login/
        let launcherAppId = "com.yuvalshavit.WhatdidLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        
        Prefs.$launchAtLogin.addListener {enabled in
            let success = SMLoginItemSetEnabled(launcherAppId as CFString, enabled)
            wdlog(success ? .info : .warn, "SMLoginItemSetEnabled -> %d %@", enabled, success ? "successfully set" : "NOT set")
        }

        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }
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
}

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}
