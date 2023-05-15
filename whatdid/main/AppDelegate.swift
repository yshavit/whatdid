// whatdid?

import Cocoa
import KeyboardShortcuts
import ServiceManagement
import Sparkle

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    public static let DEBUG_DATE_FORMATTER = ISO8601DateFormatter()

    private var _model = Model()
    @IBOutlet weak var mainMenu: MainMenu!
    private var deactivationHooks : Atomic<[() -> Void]> = Atomic(wrappedValue: [])
    private var openWindows = [ObjectIdentifier:NSWindowController]()
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: UpdaterDelegate.instance, userDriverDelegate: nil)
    
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
    
    func whenNotActive(_ block: @escaping () -> Void) {
        if NSApp.isActive {
            deactivationHooks.modifyInPlace {arr in
                arr.append(block)
            }
        } else {
            block()
        }
    }
    
    func applicationDidFinishLaunching(_: Notification) {
        wdlog(.info, "Starting whatdid with build %{public}@", Version.pretty)
        #if UI_TEST
        wdlog(.info, "initializing UI test hooks")
        uiTestWindow = UiTestWindow()
        uiTestWindow.show()
        NSApp.setActivationPolicy(.accessory)
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
        // Set up the updater
        mainMenu.appStartedUp()
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

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}
