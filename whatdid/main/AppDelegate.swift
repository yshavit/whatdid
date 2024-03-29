// whatdid?

import Cocoa
import KeyboardShortcuts
import ServiceManagement
#if canImport(Sparkle)
import Sparkle
#endif

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate, NSMenuDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    public static let DEBUG_DATE_FORMATTER = ISO8601DateFormatter()

    private var _model = Model() {
        didSet {
            UsageTracking.instance.setModel(model)
        }
    }
    
    @IBOutlet weak var mainMenu: MainMenu!
    private var deactivationHooks : Atomic<[() -> Void]> = Atomic(wrappedValue: [])
    private var openWindows = [ObjectIdentifier:NSWindowController]()
    
    #if canImport(Sparkle)
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: UpdaterDelegate.instance, userDriverDelegate: nil)
    #endif
    
    #if UI_TEST
    private var uiTestWindow: UiTestWindow!
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
        Prefs.resetRaw()
        globalLogHook.reset()
    }
    #endif
    
    func whenNotActive(_ block: @escaping () -> Void) {
        if NSApp.isActive {
            deactivationHooks.modifyInPlace {arr in
                arr.append(block)
            }
        } else {
            block()
        }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        /// This funny little bit fossilizes the tracker id the first time the app runs.
        ///
        /// The way our Prefs wrapper works, they're always initialized in-memory with a default value, and then the wrapped
        /// value returns either what's stored, or the default value. The default for the trackerId is UUID(), though, which
        /// is a random UUID that's regenerated every time the process runs. Therefore, we never want to use this, and always
        /// want there to be a stored value. That's what this does.
        ///
        /// So, the first time this app is ever launched, the read will return that randomly-generated UUID, and the write will
        /// store it. On subsequent startups, the read will fetch that stored value, and the write will idempotently re-write it.
        ///
        /// We already `UUID.zero` to represent  "a bogus UUID" — for example, if someone manually sets the UUID to
        /// `"bogus"` (which can't be parsed into a UUID) using the CLI `defaults` tool. W always want to respect
        /// the value that's there, and not regenerate a new UUID to replace it: if the user set their trackerId to something
        /// bogus, they probably had a good reason (like not wanting to be tracked).
        let trackerId = Prefs.trackerId
        if trackerId != UUID.zero {
            Prefs.trackerId = trackerId
        }
    }
    
    func applicationDidFinishLaunching(_: Notification) {
        wdlog(.info, "Starting whatdid with build %{public}@", Version.pretty)
        // Start tracking analytics (if allowed)
        UsageTracking.instance.setModel(model)
        Prefs.$analyticsEnabled.addListener(UsageTracking.instance.setEnabled(_:)) // This also schedules an initial check
        
        #if UI_TEST
        wdlog(.info, "initializing UI test hooks")
        uiTestWindow = UiTestWindow()
        uiTestWindow.show()
        NSApp.setActivationPolicy(.accessory)
        #endif
        
        AppDelegate.DEBUG_DATE_FORMATTER.timeZone = DefaultScheduler.instance.timeZone
        
        // Set up the keyboard shortcut
        KeyboardShortcuts.onKeyDown(for: .grabFocus) {
            UsageTracking.recordAction(.GlobalShortcut)
            self.mainMenu.focus()
        }
        // Set up the lanch-on-login functionality, if needed
        setUpLauncher()
        // Kick off the various scheduled popups (PTN, day start, day end).
        kickOffInitialSchedules()
        // Set up the updater
        mainMenu.appStartedUp()
    }
    
    private func kickOffInitialSchedules() {
        let persistedSchedules = Prefs.scheduledOpens
        for windowContent in MainMenu.WindowContents.allCases {
            if let persistedSchedule = persistedSchedules[windowContent] {
                mainMenu.schedule(windowContent, at: persistedSchedule)
            } else {
                mainMenu.schedule(windowContent)
            }
        }
        
        let currentVersion = Prefs.tutorialVersion
        if SHOW_TUTORIAL_ON_FIRST_START && currentVersion < PtnViewController.CURRENT_TUTORIAL_VERSION {
            mainMenu.whenPtnIsReady {ptn in
                self.mainMenu.open(.ptn, reason: .manual)
                ptn.showTutorial(forVersion: currentVersion)
            }
            Prefs.tutorialVersion = PtnViewController.CURRENT_TUTORIAL_VERSION
        }
        
        if !SILENT_STARTUP, let currentSession = model.getCurrentSession(), let sessionStart = currentSession.startTime {
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
        wdlog(.info, "whatdid is shutting down")
    }
    
    func windowOpened(_ window: NSWindowController) {
        let objectId = ObjectIdentifier(window)
        if objectId != ObjectIdentifier(mainMenu) {
            // We opened a window other than the MainMenu one, so make us a temporary window
            NSApp.setActivationPolicy(.regular)
        }
        openWindows[objectId] = window
    }
    
    func windowClosed(_ window: NSWindowController) {
        let old = openWindows.removeValue(forKey: ObjectIdentifier(window))
        if old == nil {
            wdlog(.warn, "registered a close for an unknown window controller")
        }

        if openWindows.isEmpty {
            // windowOpened(_) may have put us into .regular mode; if so, switch back
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
            NSApp.hide(self)
        }
    }
    
    func applicationDidHide(_ notification: Notification) {
        wdlog(.debug, "application did hide")
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        wdlog(.debug, "application became active")
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        wdlog(.debug, "application resigned active")
        let oldHooks = deactivationHooks.getAndSet([])
        oldHooks.forEach {hook in
            hook()
        }
    }
    
    func applicationDidChangeScreenParameters(_ notification: Notification) {
        // We want to do this first (before the other hooks), since the other hooks depend on it.
        // Specifically, AutoCompletingField's popup-mover depends on the window having already
        // moved. This is ugly, but works for now.
        mainMenu.ensureWindowCorrectLocation(fromButtonClick: false)
        screenChangeHooks.values.forEach {$0()}
    }
    
    private var screenChangeHooks = [UUID: () -> Void]()
    func registerScreenChangeHook(_ block: @escaping () -> Void) -> (() -> Void) {
        let uuid = UUID()
        screenChangeHooks[uuid] = block
        return {
            self.screenChangeHooks.removeValue(forKey: uuid)
        }
    }
    
    
    
    private func setUpLauncher() {
        // Taken from https://theswiftdev.com/how-to-launch-a-macos-app-at-login/
        let launcherAppId = "com.yuvalshavit.WhatdidLauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        
        Prefs.$launchAtLogin.addListener {enabled in
            let success = SMLoginItemSetEnabled(launcherAppId as CFString, enabled)
            wdlog(success ? .info : .warn, "SMLoginItemSetEnabled -> %d, success=%d", enabled, success)
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

#if canImport(Sparkle)
private class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    static let instance = UpdaterDelegate()
    
    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        
        Prefs.startupMessages = Prefs.startupMessages + [.updated]
        
        if let mainWindow = AppDelegate.instance.mainMenu, mainWindow.isOpen {
            AppDelegate.instance.whenNotActive(installHandler)
            mainWindow.close()
            return true
        } else {
            return false
        }
    }
    
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        let s = Set(Prefs.updateChannels.map({$0.rawValue}))
        wdlog(.debug, "Updater's allowed channels: [%@]", s.joined(separator: ", "))
        return s
    }
}
#else
fileprivate protocol SPUUpdaterDelegate {
    // dummy protocol definition to stand in for sparkle's
}
private class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    // dummy class
}
#endif

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}
