// whatdid?

import Cocoa
import HotKey

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    public static let instance = NSApplication.shared.delegate as! AppDelegate
    public static let DEBUG_DATE_FORMATTER = ISO8601DateFormatter()

    public let model = Model()
    @IBOutlet weak var mainMenu: MainMenu!
    let focusHotKey = HotKey(key: .x, modifiers: [.command, .shift])
    private var deactivationHooks : Atomic<[() -> Void]> = Atomic(wrappedValue: [])
    
    #if UI_TEST
    private var uiTestWindow : UiTestWindow!
    private var manualTickSchedulerWindow: ManualTickSchedulerWindow!
    #endif
    
    func onDeactivation(_ block: @escaping () -> Void) {
        deactivationHooks.modifyInPlace {arr in
            arr.append(block)
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("Starting whatdid with build %@", Version.pretty)
        #if UI_TEST
        NSLog("initializing UI test hooks")
        manualTickSchedulerWindow = ManualTickSchedulerWindow(with: DefaultScheduler.instance)
        if let showView = CommandLine.arguments.compactMap({DebugMode(fromStringIfWithPrefix: $0)}).first {
            uiTestWindow = UiTestWindow()
            uiTestWindow.show(showView)
        }
        NSApp.setActivationPolicy(.regular) // UI tests can time out on launch() without this
        #else
        // Our Info.plist starts us off as background. Now that we're started, become an accessory app.
        // This approach lets us start the app deactivated.
        NSApp.setActivationPolicy(.accessory)
        #endif
        
        AppDelegate.DEBUG_DATE_FORMATTER.timeZone = DefaultScheduler.instance.timeZone
        focusHotKey.keyDownHandler = { self.mainMenu.focus() }
        
        mainMenu.schedule(.ptn)
        scheduleEndOfDaySummary()
    }
    
    func scheduleEndOfDaySummary() {
        let scheduleEndOfDay = TimeUtil.dateForTime(.next, hh: 18, mm: 30)
        NSLog("Scheduling summary at %@", scheduleEndOfDay.debugDescription)
        DefaultScheduler.instance.schedule(at: scheduleEndOfDay) {
            self.mainMenu.open(.dailyEnd, reason: .scheduled)
        }
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        let oldHooks = deactivationHooks.getAndSet([])
        oldHooks.forEach {hook in
            hook()
        }
    }
    
    func snooze(until date: Date) {
        self.mainMenu.snooze(until: date)
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
